import Foundation

/// High-level translation API. Wraps `LlamaBridge` and exposes async streaming.
actor TranslatorService {

    enum State { case idle, loading, ready, busy }

    private var bridge: LlamaBridge?
    private(set) var state: State = .idle
    private(set) var loadedModelURL: URL?

    /// Lazy-load (or reload if path changed) the model.
    func ensureLoaded(modelURL: URL) async throws {
        if loadedModelURL == modelURL, bridge != nil { return }
        state = .loading
        defer { if bridge != nil { state = .ready } else { state = .idle } }

        // Apple devices: always try Metal; fall back transparently if unavailable.
        let nThreads = max(2, ProcessInfo.processInfo.activeProcessorCount - 2)
        var error: NSError?
        let b = LlamaBridge(modelPath: modelURL.path,
                            contextSize: 2048,
                            nThreads: nThreads,
                            useMetal: true,
                            error: &error)
        guard let b else {
            throw error ?? NSError(domain: "TranslatorService", code: 1)
        }
        self.bridge = b
        self.loadedModelURL = modelURL
    }

    /// Streams tokens back to the caller via `AsyncThrowingStream`.
    func translate(source: Language, target: Language, text: String)
        -> AsyncThrowingStream<String, Error>
    {
        AsyncThrowingStream { continuation in
            Task.detached(priority: .userInitiated) { [weak self] in
                guard let self else { continuation.finish(); return }
                let prompt = PromptBuilder.translation(source: source, target: target, text: text)
                let params = LBSamplingParams()
                params.temperature  = 0.2
                params.topP         = 0.9
                params.topK         = 40
                params.maxNewTokens = 512

                await self.setBusy(true)
                defer { Task { await self.setBusy(false) } }

                guard let bridge = await self.bridge else {
                    continuation.finish(throwing: NSError(domain: "TranslatorService", code: 2,
                        userInfo: [NSLocalizedDescriptionKey: "Model not loaded"]))
                    return
                }

                var error: NSError?
                _ = bridge.generate(withPrompt: prompt, params: params, onToken: { token in
                    continuation.yield(token)
                    return true
                }, error: &error)

                if let error { continuation.finish(throwing: error) }
                else         { continuation.finish() }
            }
        }
    }

    func cancel() async { bridge?.cancel() }

    private func setBusy(_ b: Bool) { state = b ? .busy : .ready }

    var lastTokensPerSecond: Double { bridge?.lastTokensPerSecond ?? 0 }
}
