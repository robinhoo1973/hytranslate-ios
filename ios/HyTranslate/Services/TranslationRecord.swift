import Foundation
import SwiftData

@Model
final class TranslationRecord {
    @Attribute(.unique) var id: UUID
    var createdAt: Date
    var sourceLangId: String
    var targetLangId: String
    var sourceText: String
    var translatedText: String
    var favorite: Bool

    init(sourceLangId: String, targetLangId: String,
         sourceText: String, translatedText: String) {
        self.id = UUID()
        self.createdAt = .now
        self.sourceLangId = sourceLangId
        self.targetLangId = targetLangId
        self.sourceText = sourceText
        self.translatedText = translatedText
        self.favorite = false
    }
}
