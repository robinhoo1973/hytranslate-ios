# HyTranslate

Offline iOS / macOS / iPad translation app powered by Tencent **Hy-MT1.5-1.8B**
running on-device through `llama.cpp` (Metal + Accelerate). The model is
re-quantized to GGUF k-quants from the BF16 source published by Tencent;
AngelSlim's 2-bit Sherry weights are not used because no Apple-side dequant
kernel exists yet.

> **Status:** scaffold complete, awaiting a macOS machine (or CI runner) for
> the first real Xcode build. Linux-side validation of the GGUF model and
> prompt template is fully supported via `tools/`.

## Layout

| Path | Purpose |
|---|---|
| `ios/`        | SwiftUI + SwiftData iOS / iPad / Mac Catalyst app. Generated with XcodeGen. |
| `cli/`        | macOS SwiftPM CLI that reuses the iOS bridge for desktop validation. |
| `tools/`      | Linux-friendly shell scripts: GGUF conversion + smoke tests. |
| `.github/`    | GitHub Actions: free macOS runner builds the simulator app + screenshots. |

## Quick start (Linux, no Apple hardware)

```bash
# Convert + quantize Hy-MT1.5-1.8B to GGUF (one-time, ~3.6 GB download)
bash tools/convert_hy_mt_to_gguf.sh

# Translate something using llama.cpp's native CLI
bash tools/linux_smoke_test.sh
```

## Quick start (macOS)

```bash
brew install xcodegen
cd ios && xcodegen generate && open HyTranslate.xcodeproj
```

See [ios/README.md](ios/README.md) for full build/signing instructions and
[cli/README.md](cli/README.md) for the macOS CLI demo.

## Continuous integration

`.github/workflows/ios-simulator.yml` runs on every push: it converts the
model, builds the iOS app, boots an iOS 17 simulator, sideloads the GGUF, and
uploads launch screenshots as artifacts. **No Apple Developer account is
required** — the workflow uses `CODE_SIGNING_ALLOWED=NO` and never produces a
signed `.ipa`.

## License

App code: see source files. Hy-MT1.5 model weights and the AngelSlim toolkit
are subject to Tencent's licenses; review them before redistribution.
