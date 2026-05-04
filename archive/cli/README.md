# HyTranslate CLI (macOS desktop validation)

Minimal command-line client that reuses the **same** llama.cpp Obj-C++ bridge
and prompt template the iOS app uses. Run it on macOS 13+ to validate a GGUF
build before flashing it onto a device.

## Build

```bash
cd cli
swift build -c release
```

The first build pulls `https://github.com/ggerganov/llama.cpp` (master) and
`swift-argument-parser`. Metal kernels are compiled by llama.cpp's SwiftPM
manifest automatically.

## Run

```bash
swift run -c release hytranslate \
    --model ../tools/build/models/hy-mt-1.8b.Q4_K_M.gguf \
    --from zh --to en \
    "人工智能正在改变世界。"
```

Useful flags:

| flag                | default  | meaning                                   |
|---------------------|----------|-------------------------------------------|
| `--from / -f`       | `auto`   | source language id (BCP-47 or `auto`)     |
| `--to / -t`         | `en`     | target language id                        |
| `--temperature`     | `0.2`    | sampling temperature                      |
| `--max-tokens`      | `512`    | generation cap                            |
| `--context-size`    | `2048`   | n_ctx                                     |
| `--no-metal`        | off      | force CPU backend                         |
| `--dry-run`         | off      | print the formatted prompt and exit       |

Pass `-` as the argument to read text from stdin:

```bash
echo "今天天气真好。" | swift run -c release hytranslate -m model.gguf -f zh -t en -
```

## How sources are shared with the iOS app

The four files below are **symlinked** from `ios/HyTranslate/`, so any change
(e.g. a prompt-template fix) immediately benefits both targets:

| in CLI                                                | resolves to                                 |
|-------------------------------------------------------|---------------------------------------------|
| `Sources/LlamaBridgeKit/include/LlamaBridge.h`        | `ios/HyTranslate/Bridge/LlamaBridge.h`      |
| `Sources/LlamaBridgeKit/LlamaBridge.mm`               | `ios/HyTranslate/Bridge/LlamaBridge.mm`     |
| `Sources/HyTranslateCore/LanguageCatalog.swift`       | `ios/HyTranslate/Services/LanguageCatalog.swift` |
| `Sources/HyTranslateCore/PromptBuilder.swift`         | `ios/HyTranslate/Services/PromptBuilder.swift`   |

## Smoke test the prompt template

```bash
swift run hytranslate --dry-run -m /dev/null -f zh -t en "你好"
```

Expected output begins with `<｜hy_begin▁of▁sentence｜><｜hy_User｜>请将下面的中文…` —
note the **full-width** `｜` characters (U+FF5C). If you see ASCII `|`, the
template is wrong and the model will produce garbage.
