#!/usr/bin/env bash
# M0: Convert Tencent Hy-MT1.5-1.8B (BF16) to GGUF and quantize for iOS.
#
# Why BF16 source instead of AngelSlim's 1.25-bit / 2-bit Sherry weights?
#   The Sherry quantization format is a custom CUDA kernel; llama.cpp / Metal
#   has no dequant routine for it. We re-quantize from BF16 into GGUF k-quants
#   that are natively supported on Apple Silicon.
#
# Output (in $OUT_DIR):
#   hy-mt-1.8b.f16.gguf       ~3.6 GB   (intermediate, can delete)
#   hy-mt-1.8b.Q4_K_M.gguf    ~1.1 GB   (default, quality-first, A14+)
#   hy-mt-1.8b.Q3_K_M.gguf    ~0.9 GB   (fallback for iPhone XR / 3 GB RAM)
#   hy-mt-1.8b.IQ3_M.gguf     ~0.8 GB   (alternative low-RAM build)
set -euo pipefail

REPO_ID="${REPO_ID:-tencent/HY-MT1.5-1.8B}"
OUT_DIR="${OUT_DIR:-$(pwd)/build/models}"
LLAMA_CPP_DIR="${LLAMA_CPP_DIR:-$(pwd)/build/llama.cpp}"
# Comma- or space-separated list of quants to produce. Default: full set.
# CI overrides this to just Q3_K_M to save time and disk.
QUANTS="${QUANTS:-Q4_K_M Q3_K_M IQ3_M}"
# Set SMOKE_TEST=0 to skip the llama-cli smoke run (CI uses 0).
SMOKE_TEST="${SMOKE_TEST:-1}"
# Stream Python output unbuffered so tqdm progress bars appear in CI logs.
export PYTHONUNBUFFERED=1
# hf_transfer = parallel multi-connection downloader, ~5-10x faster + resilient
# to single-connection stalls that hf_hub's default downloader can suffer from.
export HF_HUB_ENABLE_HF_TRANSFER="${HF_HUB_ENABLE_HF_TRANSFER:-1}"
export HF_HUB_DOWNLOAD_TIMEOUT="${HF_HUB_DOWNLOAD_TIMEOUT:-20}"

mkdir -p "$OUT_DIR" "$(dirname "$LLAMA_CPP_DIR")"

# --- 1. Fetch source weights -------------------------------------------------
# We bypass `hf download` because in CI it stalled silently for 60+ min on the
# 3.6 GB .safetensors file even with hf_transfer enabled. aria2c gives us
# multi-connection downloads with explicit per-connection timeouts.
if [[ ! -d "$OUT_DIR/src" ]] || [[ ! -f "$OUT_DIR/src/model.safetensors" ]]; then
  echo ">>> Downloading $REPO_ID files via aria2c ..."
  mkdir -p "$OUT_DIR/src"
  REVISION="${MODEL_REVISION:-main}"
  BASE="https://huggingface.co/${REPO_ID}/resolve/${REVISION}"
  AUTH_HEADER=()
  if [[ -n "${HUGGING_FACE_HUB_TOKEN:-}" ]]; then
    AUTH_HEADER+=(--header="Authorization: Bearer ${HUGGING_FACE_HUB_TOKEN}")
  fi
  # Files come from the model repo's siblings list. Keep this in sync if
  # upstream adds files. The big one is model.safetensors (~3.6 GB).
  for f in \
      config.json \
      generation_config.json \
      tokenizer.json \
      tokenizer_config.json \
      special_tokens_map.json \
      chat_template.jinja \
      model.safetensors ; do
    if [[ -f "$OUT_DIR/src/$f" ]]; then
      echo "    skip (cached): $f"
      continue
    fi
    echo "    fetch: $f"
    aria2c \
      --console-log-level=warn \
      --summary-interval=10 \
      -x 16 -s 16 -k 1M \
      --connect-timeout=20 \
      --timeout=30 \
      --max-tries=5 \
      --retry-wait=5 \
      --auto-file-renaming=false \
      --allow-overwrite=true \
      ${AUTH_HEADER[@]+"${AUTH_HEADER[@]}"} \
      -d "$OUT_DIR/src" -o "$f" \
      "${BASE}/${f}"
  done
fi

# --- 2. Locate llama.cpp tools ----------------------------------------------
# Prefer brew-installed binaries (CI uses this path: ~10x faster than building
# from source). Falls back to a local source build for hermetic local runs.
LLAMA_QUANTIZE="${LLAMA_QUANTIZE:-$(command -v llama-quantize || true)}"
LLAMA_CLI="${LLAMA_CLI:-$(command -v llama-cli || true)}"

if [[ -z "$LLAMA_QUANTIZE" || ! -x "$LLAMA_QUANTIZE" ]]; then
  echo ">>> No system llama-quantize; cloning & building from source ..."
  [[ -d "$LLAMA_CPP_DIR" ]] || git clone --depth 1 https://github.com/ggerganov/llama.cpp "$LLAMA_CPP_DIR"
  if [[ ! -x "$LLAMA_CPP_DIR/build/bin/llama-quantize" ]]; then
    cmake -S "$LLAMA_CPP_DIR" -B "$LLAMA_CPP_DIR/build" -DGGML_METAL=OFF -DLLAMA_CURL=OFF
    cmake --build "$LLAMA_CPP_DIR/build" -j --target llama-quantize llama-cli
  fi
  LLAMA_QUANTIZE="$LLAMA_CPP_DIR/build/bin/llama-quantize"
  LLAMA_CLI="$LLAMA_CPP_DIR/build/bin/llama-cli"
fi

# convert_hf_to_gguf.py + requirements.txt only live in the source tree, so we
# always need a (shallow) clone for the python conversion script.
if [[ ! -f "$LLAMA_CPP_DIR/convert_hf_to_gguf.py" ]]; then
  echo ">>> Shallow-cloning llama.cpp for conversion script ..."
  rm -rf "$LLAMA_CPP_DIR"
  git clone --depth 1 --filter=blob:none https://github.com/ggerganov/llama.cpp "$LLAMA_CPP_DIR"
fi
python -m pip install -q -r "$LLAMA_CPP_DIR/requirements/requirements-convert_hf_to_gguf.txt" \
  || python -m pip install -q -r "$LLAMA_CPP_DIR/requirements.txt"

# --- 3. HF -> GGUF (f16 intermediate) ---------------------------------------
F16="$OUT_DIR/hy-mt-1.8b.f16.gguf"
if [[ ! -f "$F16" ]]; then
  echo ">>> Converting HF -> GGUF (f16) ..."
  python "$LLAMA_CPP_DIR/convert_hf_to_gguf.py" "$OUT_DIR/src" --outtype f16 --outfile "$F16"
fi

# --- 4. Quantize to the requested target sizes ------------------------------
for tag in $(echo "$QUANTS" | tr ',' ' '); do
  out="$OUT_DIR/hy-mt-1.8b.${tag}.gguf"
  if [[ ! -f "$out" ]]; then
    echo ">>> Quantizing -> $tag"
    "$LLAMA_QUANTIZE" "$F16" "$out" "$tag"
  fi
done

# --- 5. Smoke test (CPU) ----------------------------------------------------
if [[ "$SMOKE_TEST" == "1" ]] && [[ -f "$OUT_DIR/hy-mt-1.8b.Q4_K_M.gguf" ]]; then
  echo ">>> Smoke test on Q4_K_M:"
  "$LLAMA_CLI" \
    -m "$OUT_DIR/hy-mt-1.8b.Q4_K_M.gguf" \
    -no-cnv -n 64 -t 4 \
    -p $'Translate the following Chinese sentence into English:\n人工智能正在改变世界。\nEnglish:'
fi

echo
echo "Done. Upload these three .gguf files to your CDN / HuggingFace mirror"
echo "and reference them from ios/HyTranslate/Resources/model_manifest.json"
