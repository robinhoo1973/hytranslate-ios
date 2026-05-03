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
if [[ ! -d "$OUT_DIR/src" ]]; then
  echo ">>> Downloading $REPO_ID from HuggingFace ..."
  # huggingface_hub >=1.0 renamed the CLI from `huggingface-cli` to `hf`.
  # hf_transfer enables the high-throughput Rust downloader.
  python -m pip install -q -U "huggingface_hub>=1.0" hf_transfer
  hf download "$REPO_ID" --local-dir "$OUT_DIR/src"
fi

# --- 2. Build llama.cpp tools ------------------------------------------------
if [[ ! -x "$LLAMA_CPP_DIR/build/bin/llama-quantize" ]]; then
  echo ">>> Cloning & building llama.cpp ..."
  [[ -d "$LLAMA_CPP_DIR" ]] || git clone --depth 1 https://github.com/ggerganov/llama.cpp "$LLAMA_CPP_DIR"
  cmake -S "$LLAMA_CPP_DIR" -B "$LLAMA_CPP_DIR/build" -DGGML_METAL=OFF -DLLAMA_CURL=OFF
  cmake --build "$LLAMA_CPP_DIR/build" -j --target llama-quantize llama-cli
  python -m pip install -q -r "$LLAMA_CPP_DIR/requirements.txt"
fi

# --- 3. HF -> GGUF (f16 intermediate) ---------------------------------------
F16="$OUT_DIR/hy-mt-1.8b.f16.gguf"
if [[ ! -f "$F16" ]]; then
  echo ">>> Converting HF -> GGUF (f16) ..."
  python "$LLAMA_CPP_DIR/convert_hf_to_gguf.py" "$OUT_DIR/src" --outtype f16 --outfile "$F16"
fi

# --- 4. Quantize to the requested target sizes ------------------------------
QUANT="$LLAMA_CPP_DIR/build/bin/llama-quantize"
for tag in $(echo "$QUANTS" | tr ',' ' '); do
  out="$OUT_DIR/hy-mt-1.8b.${tag}.gguf"
  if [[ ! -f "$out" ]]; then
    echo ">>> Quantizing -> $tag"
    "$QUANT" "$F16" "$out" "$tag"
  fi
done

# --- 5. Smoke test (CPU) ----------------------------------------------------
if [[ "$SMOKE_TEST" == "1" ]] && [[ -f "$OUT_DIR/hy-mt-1.8b.Q4_K_M.gguf" ]]; then
  echo ">>> Smoke test on Q4_K_M:"
  "$LLAMA_CPP_DIR/build/bin/llama-cli" \
    -m "$OUT_DIR/hy-mt-1.8b.Q4_K_M.gguf" \
    -no-cnv -n 64 -t 4 \
    -p $'Translate the following Chinese sentence into English:\n人工智能正在改变世界。\nEnglish:'
fi

echo
echo "Done. Upload these three .gguf files to your CDN / HuggingFace mirror"
echo "and reference them from ios/HyTranslate/Resources/model_manifest.json"
