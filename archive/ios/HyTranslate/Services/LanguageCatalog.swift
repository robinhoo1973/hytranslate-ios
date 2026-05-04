import Foundation

/// One of Hy-MT's supported languages. Codes follow BCP-47 / ISO-639-1 where possible.
public struct Language: Identifiable, Hashable, Codable, Sendable {
    public let id: String         // BCP-47 code, e.g. "zh", "en", "ja"
    public let nativeName: String // 中文, English, 日本語
    public let displayName: String// shown in zh-CN UI
    public let promptName: String // exact name fed to the model prompt template

    public init(id: String, nativeName: String, displayName: String, promptName: String) {
        self.id = id; self.nativeName = nativeName
        self.displayName = displayName; self.promptName = promptName
    }
}

public enum LanguageCatalog {
    /// Hy-MT1.5 supports ~33 languages. This is the curated subset shipped in v1.
    /// Order ≈ usage frequency, then alphabetical.
    public static let all: [Language] = [
        .init(id: "auto", nativeName: "Auto", displayName: "自动检测",   promptName: "auto"),
        .init(id: "zh",   nativeName: "中文",  displayName: "中文",       promptName: "中文"),
        .init(id: "en",   nativeName: "English", displayName: "英文",     promptName: "英文"),
        .init(id: "ja",   nativeName: "日本語",  displayName: "日文",     promptName: "日文"),
        .init(id: "ko",   nativeName: "한국어",  displayName: "韩文",     promptName: "韩文"),
        .init(id: "fr",   nativeName: "Français", displayName: "法文",    promptName: "法文"),
        .init(id: "de",   nativeName: "Deutsch",  displayName: "德文",    promptName: "德文"),
        .init(id: "es",   nativeName: "Español",  displayName: "西班牙文", promptName: "西班牙文"),
        .init(id: "pt",   nativeName: "Português", displayName: "葡萄牙文", promptName: "葡萄牙文"),
        .init(id: "ru",   nativeName: "Русский",  displayName: "俄文",    promptName: "俄文"),
        .init(id: "it",   nativeName: "Italiano", displayName: "意大利文", promptName: "意大利文"),
        .init(id: "ar",   nativeName: "العربية",  displayName: "阿拉伯文", promptName: "阿拉伯文"),
        .init(id: "th",   nativeName: "ไทย",     displayName: "泰文",     promptName: "泰文"),
        .init(id: "vi",   nativeName: "Tiếng Việt", displayName: "越南文",  promptName: "越南文"),
        .init(id: "id",   nativeName: "Bahasa Indonesia", displayName: "印尼文", promptName: "印尼文"),
        .init(id: "ms",   nativeName: "Bahasa Melayu", displayName: "马来文", promptName: "马来文"),
        .init(id: "tr",   nativeName: "Türkçe",   displayName: "土耳其文", promptName: "土耳其文"),
        .init(id: "nl",   nativeName: "Nederlands", displayName: "荷兰文", promptName: "荷兰文"),
        .init(id: "pl",   nativeName: "Polski",   displayName: "波兰文",   promptName: "波兰文"),
        .init(id: "hi",   nativeName: "हिन्दी",     displayName: "印地文",   promptName: "印地文"),
    ]

    public static func by(id: String) -> Language {
        all.first(where: { $0.id == id }) ?? all[1]
    }

    /// Targets exclude "auto".
    public static var targets: [Language] { all.filter { $0.id != "auto" } }
}
