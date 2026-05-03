#!/usr/bin/env bash
# Linux-side end-to-end validation of the Hy-MT1.5 GGUF + prompt template.
#
# Mirrors what cli/Sources/HyTranslateCLI/main.swift would do on macOS, but
# uses llama.cpp's native llama-cli binary so it works without Swift / Apple
# toolchain. Run AFTER tools/convert_hy_mt_to_gguf.sh has produced a .gguf.
#
# Usage:
#   tools/linux_smoke_test.sh [path/to/model.gguf] [src_lang] [tgt_lang] [text]
#
# Defaults translate Chinese -> English with Q4_K_M build.
#
# IMPORTANT: the special tokens below use FULL-WIDTH '｜' (U+FF5C), matching
# AngelSlim/Hy-MT1.5-1.8B-2bit/tokenizer_config.json. Do NOT replace them with
# ASCII '|' or the model will produce garbage.
set -euo pipefail

MODEL="${1:-build/models/hy-mt-1.8b.Q4_K_M.gguf}"
SRC="${2:-中文}"
TGT="${3:-英文}"
TEXT="${4:-人工智能正在改变世界。}"

LLAMA_CLI="${LLAMA_CLI:-build/llama.cpp/build/bin/llama-cli}"

if [[ ! -f "$MODEL" ]]; then
  echo "[smoke] model not found: $MODEL" >&2
  echo "[smoke] run tools/convert_hy_mt_to_gguf.sh first." >&2
  exit 1
fi
if [[ ! -x "$LLAMA_CLI" ]]; then
  echo "[smoke] llama-cli not found: $LLAMA_CLI" >&2
  echo "[smoke] set LLAMA_CLI or rerun tools/convert_hy_mt_to_gguf.sh." >&2
  exit 1
fi

BOS=$'<\xef\xbd\x9chy_begin\xe2\x96\x81of\xe2\x96\x81sentence\xef\xbd\x9c>'   # <｜hy_begin▁of▁sentence｜>
USR=$'<\xef\xbd\x9chy_User\xef\xbd\x9c>'                                       # <｜hy_User｜>
AST=$'<\xef\xbd\x9chy_Assistant\xef\xbd\x9c>'                                  # <｜hy_Assistant｜>

INSTRUCTION="请将下面的${SRC}文本翻译成${TGT}，只输出译文，不要解释或添加其他内容。

${TEXT}"

PROMPT="${BOS}${USR}${INSTRUCTION}${AST}"

echo "[smoke] --- prompt (hex of first 64 bytes) ---" >&2
printf '%s' "$PROMPT" | head -c 64 | xxd >&2
echo "[smoke] --- generation ---" >&2

# -no-cnv : raw completion mode, no built-in chat template applied
# -sp     : print special tokens so we can verify <｜hy_EOT｜> / EOS appear
# Adjust -ngl if you have a CUDA build.
"$LLAMA_CLI" \
    -m "$MODEL" \
    -p "$PROMPT" \
    --temp 0.2 --top-p 0.9 --top-k 40 \
    -n 512 -c 2048 \
    -no-cnv -sp \
    --no-display-prompt
