#!/usr/bin/env bash
# Fetches the prebuilt llama.cpp xcframework into the given directory.
# Usage: tools/fetch_llama_xcframework.sh [dest_dir] [tag]
set -euo pipefail

DEST="${1:-ios/Frameworks}"
TAG="${2:-b9010}"
URL="https://github.com/ggml-org/llama.cpp/releases/download/${TAG}/llama-${TAG}-xcframework.zip"

mkdir -p "$DEST"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

echo "Fetching $URL"
if command -v aria2c >/dev/null 2>&1; then
  aria2c -x 8 -s 8 --console-log-level=warn --summary-interval=0 \
    -d "$TMP" -o llama.zip "$URL"
else
  curl -L --fail -o "$TMP/llama.zip" "$URL"
fi

echo "Extracting..."
unzip -q "$TMP/llama.zip" -d "$TMP"
# Archive layout: build-apple/llama.xcframework/...
rm -rf "$DEST/llama.xcframework"
mv "$TMP/build-apple/llama.xcframework" "$DEST/llama.xcframework"
echo "Installed: $DEST/llama.xcframework"
