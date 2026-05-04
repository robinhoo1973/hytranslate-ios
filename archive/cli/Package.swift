// swift-tools-version: 5.10
// Standalone macOS CLI that exercises the same llama.cpp bridge and
// prompt template used by the iOS app. Run on macOS 13+ to validate the
// end-to-end pipeline before opening Xcode.
//
//   # one-time: fetch the prebuilt llama.cpp xcframework into ./Frameworks/
//   ../tools/fetch_llama_xcframework.sh cli/Frameworks
//
//   cd cli
//   swift run hytranslate \
//       --model ../tools/build/models/hy-mt-1.8b.Q4_K_M.gguf \
//       --from zh --to en \
//       "人工智能正在改变世界。"
//
// The CLI shares its core sources with the iOS app via symlinked paths so that
// any prompt-template fix lands in both places.

import PackageDescription

let package = Package(
    name: "HyTranslateCLI",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "hytranslate", targets: ["HyTranslateCLI"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.3.0"),
    ],
    targets: [
        // Prebuilt llama.cpp framework. Fetch via tools/fetch_llama_xcframework.sh.
        .binaryTarget(
            name: "llama",
            path: "Frameworks/llama.xcframework"
        ),
        // Objective-C++ wrapper around llama.cpp (same file used by iOS).
        .target(
            name: "LlamaBridgeKit",
            dependencies: ["llama"],
            path: "Sources/LlamaBridgeKit",
            publicHeadersPath: "include",
            cxxSettings: [
                .define("ACCELERATE_NEW_LAPACK"),
            ]
        ),
        // Pure-Swift services (Language catalog, prompt template).
        .target(
            name: "HyTranslateCore",
            dependencies: ["LlamaBridgeKit"],
            path: "Sources/HyTranslateCore"
        ),
        .executableTarget(
            name: "HyTranslateCLI",
            dependencies: [
                "HyTranslateCore",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ],
            path: "Sources/HyTranslateCLI"
        ),
    ],
    cxxLanguageStandard: .cxx17
)
