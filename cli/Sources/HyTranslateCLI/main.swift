import Foundation
import ArgumentParser
import HyTranslateCore
import LlamaBridgeKit

@main
struct HyTranslate: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "hytranslate",
        abstract: "Offline translation CLI powered by Tencent Hy-MT1.5 + llama.cpp.",
        discussion: """
        Validates the same prompt template and bridge layer used by the iOS app.
        Useful for testing GGUF builds before shipping them via the model manifest.
        """
    )

    @Option(name: .shortAndLong, help: "Path to the .gguf model file.")
    var model: String

    @Option(name: [.customShort("f"), .long], help: "Source language id (BCP-47, or 'auto').")
    var from: String = "auto"

    @Option(name: [.customShort("t"), .long], help: "Target language id (BCP-47).")
    var to: String = "en"

    @Option(name: .long, help: "Sampling temperature.")
    var temperature: Double = 0.2

    @Option(name: .long, help: "Max tokens to generate.")
    var maxTokens: Int = 512

    @Option(name: .long, help: "Context size (n_ctx).")
    var contextSize: Int = 2048

    @Flag(name: .long, help: "Disable Metal backend (use CPU only).")
    var noMetal: Bool = false

    @Flag(name: .long, help: "Print the raw prompt fed to the model and exit.")
    var dryRun: Bool = false

    @Argument(help: "Text to translate. Pass '-' to read from stdin.")
    var text: String

    func run() throws {
        let src = LanguageCatalog.by(id: from)
        let tgt = LanguageCatalog.by(id: to)
        guard tgt.id != "auto" else {
            throw ValidationError("--to cannot be 'auto'.")
        }

        let body: String
        if text == "-" {
            body = String(data: FileHandle.standardInput.readDataToEndOfFile(),
                          encoding: .utf8) ?? ""
        } else {
            body = text
        }

        let prompt = PromptBuilder.translation(source: src, target: tgt, text: body)

        if dryRun {
            print("--- prompt ---")
            print(prompt)
            print("--- end ---")
            return
        }

        FileHandle.standardError.write(Data(
            "[hytranslate] loading \(model) (metal=\(!noMetal)) ...\n".utf8))

        var nsError: NSError?
        guard let bridge = LlamaBridge(modelPath: model,
                                       contextSize: contextSize,
                                       nThreads: 0,
                                       useMetal: !noMetal,
                                       error: &nsError) else {
            throw RuntimeError("Failed to load model: \(nsError?.localizedDescription ?? "unknown")")
        }

        let params = LBSamplingParams()
        params.temperature  = Float(temperature)
        params.topP         = 0.9
        params.topK         = 40
        params.maxNewTokens = maxTokens

        let stdout = FileHandle.standardOutput
        FileHandle.standardError.write(Data("[hytranslate] generating ...\n".utf8))

        var error: NSError?
        _ = bridge.generate(withPrompt: prompt, params: params, onToken: { token in
            stdout.write(Data(token.utf8))
            return true
        }, error: &error)

        stdout.write(Data("\n".utf8))
        if let error {
            FileHandle.standardError.write(Data("[hytranslate] error: \(error.localizedDescription)\n".utf8))
            throw ExitCode(1)
        }

        FileHandle.standardError.write(Data(String(
            format: "[hytranslate] %.1f tok/s, %d tokens\n",
            bridge.lastTokensPerSecond, bridge.lastTokenCount).utf8))
    }
}

struct RuntimeError: Error, CustomStringConvertible {
    let description: String
    init(_ s: String) { self.description = s }
}
