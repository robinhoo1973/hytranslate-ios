# HyTranslate

Cross-platform offline translation app powered by Tencent **Hy-MT1.5-1.8B**
(via [`fllama`](https://github.com/Telosnex/fllama) → llama.cpp).

| Tier        | Layout                                                       |
|-------------|--------------------------------------------------------------|
| UI / app    | Flutter 3.41+ — Linux, Windows, Android (macOS/iOS untested) |
| Inference   | `fllama` (FFI, native llama.cpp) — Metal/Vulkan/CPU backends |
| Model       | Tencent `tencent/HY-MT1.5-1.8B` → Q3_K_M GGUF (~0.9 GB)      |

> The previous native iOS/Swift implementation has been moved to
> [`archive/ios`](archive/ios). It is no longer built by CI but kept for
> reference. The CI workflow that drove it is at
> [`archive/ios-simulator.yml.disabled`](archive/ios-simulator.yml.disabled).

## Repo layout

```
app/                Flutter project (linux, windows, android targets)
tools/              Model conversion + smoke-test scripts
archive/            Read-only: previous native iOS implementation
.github/workflows/  CI — currently Linux desktop build + screenshot
```

## Run locally (Linux)

```bash
sudo apt install clang cmake ninja-build pkg-config libgtk-3-dev liblzma-dev
cd app
flutter pub get
flutter run -d linux
```

The first build of `fllama` compiles llama.cpp via Dart's native-asset hooks;
expect a few minutes. Subsequent builds are incremental.

## Provide a model

The app looks for a GGUF at:

```
<app-documents-directory>/models/hy-mt-1.8b.Q3_K_M.gguf
```

You can also use the folder icon in the title bar to pick any `.gguf` from
disk.

To produce that file from the upstream HF checkpoint (BF16 → f16 → Q3_K_M):

```bash
brew install llama.cpp                       # macOS / Linuxbrew
# OR build llama-quantize from source — the tools/ script falls back to that
tools/convert_hy_mt_to_gguf.sh build/models  # outputs hy-mt-1.8b.Q3_K_M.gguf
```

Drop the resulting GGUF into the documents directory listed in the app's
status bar.

## CI

[`linux-desktop.yml`](.github/workflows/linux-desktop.yml) builds the Linux
bundle on `ubuntu-latest`, launches it under Xvfb, captures a launch
screenshot, and uploads everything as artifacts.

## License

Source code: MIT (see [LICENSE](LICENSE) when added).
Model weights are subject to Tencent's Hy-MT1.5 license terms.
