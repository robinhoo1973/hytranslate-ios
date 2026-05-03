import Foundation
import SwiftUI

@MainActor
final class TranslationViewModel: ObservableObject {

    @Published var sourceLang: Language = LanguageCatalog.by(id: "auto")
    @Published var targetLang: Language = LanguageCatalog.by(id: "en")
    @Published var inputText: String = ""
    @Published private(set) var outputText: String = ""
    @Published private(set) var isTranslating = false
    @Published private(set) var lastTPS: Double = 0
    @Published var errorMessage: String?

    private let translator = TranslatorService()
    private var currentTask: Task<Void, Never>?

    func swap() {
        guard sourceLang.id != "auto" else { return }
        let tmp = sourceLang; sourceLang = targetLang; targetLang = tmp
    }

    func translate() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        guard let modelURL = ModelStore.shared.activeModelURL() else {
            errorMessage = "请先在「模型管理」中下载模型"
            return
        }

        currentTask?.cancel()
        outputText = ""
        isTranslating = true
        errorMessage = nil

        currentTask = Task { [weak self] in
            guard let self else { return }
            do {
                try await self.translator.ensureLoaded(modelURL: modelURL)
                let stream = await self.translator.translate(
                    source: self.sourceLang, target: self.targetLang, text: text)
                for try await token in stream {
                    self.outputText.append(token)
                }
                self.lastTPS = await self.translator.lastTokensPerSecond
            } catch {
                self.errorMessage = error.localizedDescription
            }
            self.isTranslating = false
        }
    }

    func cancel() {
        Task { await translator.cancel() }
        currentTask?.cancel()
        isTranslating = false
    }
}
