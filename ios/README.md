# HyTranslate (iOS)

iPhone / iPad / Mac Catalyst 版离线翻译应用，后端使用经 **Tencent AngelSlim**
工具链压缩的混元 **Hy-MT1.5-1.8B** 翻译模型，通过 `llama.cpp` 在 Apple 设备上
本地推理。

> 翻译全程离线，不上传任何用户文本。

## 项目结构

```
ios/
├── project.yml                    # XcodeGen 工程描述
└── HyTranslate/
    ├── HyTranslateApp.swift       # @main 入口（TabView：翻译/历史/设置）
    ├── HyTranslate-Bridging-Header.h
    ├── Info.plist
    ├── Bridge/                    # Objective-C++ <-> llama.cpp
    │   ├── LlamaBridge.h
    │   └── LlamaBridge.mm
    ├── Services/
    │   ├── LanguageCatalog.swift  # 20+ 语言元数据
    │   ├── PromptBuilder.swift    # 混元 chat template
    │   ├── ModelStore.swift       # 下载/选择/删除 GGUF
    │   ├── TranslationRecord.swift# SwiftData 模型
    │   └── TranslatorService.swift# AsyncStream 流式 API
    ├── ViewModels/
    │   └── TranslationViewModel.swift
    ├── Views/
    │   ├── TranslateView.swift
    │   ├── LanguagePickerView.swift
    │   ├── HistoryView.swift
    │   ├── ModelManagerView.swift
    │   └── SettingsView.swift
    └── Resources/
        └── model_manifest.json    # CDN 上的可用 GGUF 列表
tools/
└── convert_hy_mt_to_gguf.sh       # M0：BF16 → GGUF → Q4_K_M / Q3_K_M / IQ3_M
```

## 构建步骤

### 1. 准备模型 (一次性，在 macOS / Linux 上)

```bash
brew install cmake huggingface-cli  # macOS
bash tools/convert_hy_mt_to_gguf.sh
```

产物 `build/models/hy-mt-1.8b.{Q4_K_M,Q3_K_M,IQ3_M}.gguf` 上传到你的 CDN，
然后把 URL 与 SHA256 写回 `ios/HyTranslate/Resources/model_manifest.json`。

### 2. 生成 Xcode 工程

```bash
brew install xcodegen
cd ios && xcodegen generate
open HyTranslate.xcodeproj
```

XcodeGen 会自动通过 SwiftPM 拉取 `llama.cpp`（Metal 后端默认开启）。

### 3. 签名与运行

1. 在 Xcode 中选中 target，填写 Development Team；
2. 真机调试推荐 iPhone 12 / A14 及以上；iPhone XR 等 3 GB RAM 设备上 `ModelStore` 会自动推荐 `Q3_K_M`；
3. 首次启动 → 「设置 → 模型管理」→ 下载推荐版本。

## 设备适配策略

| 设备 RAM | 推荐量化 | 体积 | 预期速度 |
|---|---|---|---|
| ≥ 4 GB (A14+) | `Q4_K_M` | 1.1 GB | 20–35 tok/s |
| < 4 GB (A12/XR/SE2) | `Q3_K_M` | 0.9 GB | 12–20 tok/s |

`ModelStore.recommendedBuildId()` 通过 `ProcessInfo.physicalMemory` 自动选择，
用户也可在「模型管理」中手动覆盖。

## 关键设计权衡

1. **为什么不直接用 AngelSlim 的 1.25-bit Sherry 权重？**
   Sherry 是 CUDA 自定义量化，无 Metal/CPU 反量化算子。Apple Silicon 上目前
   仅 GGUF k-quants 路线成熟，故从 BF16 重新量化。后续若 AngelSlim 团队提供
   Metal kernel，可在 `Bridge/` 层无缝替换。

2. **Bridge 层用 Objective-C++ 而非 C 包装。**
   llama.cpp 的 sampler chain 与 batch API 用 C++ 容器更顺手，同时 Swift 通过
   bridging header 调用 ObjC 完全透明。

3. **流式输出走 `AsyncThrowingStream`。**
   Bridge 用 block 回调把 token 推到 stream，UI 端 `for try await` 实时追加，
   体感与在线翻译一致。取消通过 `LlamaBridge.cancel()` 设置原子标志位实现。

4. **模型仅在 Wi-Fi 下载** (`URLSessionConfiguration.allowsCellularAccess = false`)，
   避免误用蜂窝流量下载 1 GB 文件。

## 路线图

- v1.0：本仓库当前内容（翻译 + 历史 + 模型管理）。
- v1.1：分享扩展（Share Extension），从 Safari/任意 App 选中文本直接翻译。
- v1.2：剪贴板自动翻译；TTS 朗读 (`AVSpeechSynthesizer`)。
- v2.0：相机 OCR 翻译 (VisionKit `DataScannerViewController`)。
- v2.x：跟进 AngelSlim Sherry 1.25-bit 的 Metal 后端，把模型压到 ~400 MB。

## 许可与致谢

- **Tencent AngelSlim** — 模型压缩工具链，详见 https://github.com/tencent/AngelSlim
- **Hy-MT1.5-1.8B** — Tencent Hunyuan 翻译模型，权重许可见 HuggingFace 仓库
- **llama.cpp** (MIT) — 设备端推理引擎

App 内「设置 → 关于」页面会展示上述链接与致谢，符合上架要求。
