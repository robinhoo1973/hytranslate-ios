/// One Hy-MT-supported translation language.
class Language {
  final String id; // BCP-47 / "auto"
  final String nativeName;
  final String displayName; // Chinese label shown in UI
  final String promptName; // exact term fed into the prompt template
  const Language({
    required this.id,
    required this.nativeName,
    required this.displayName,
    required this.promptName,
  });
}

/// Curated subset of Hy-MT1.5's supported languages, ported 1:1 from the
/// archived Swift catalog so the prompt strings remain identical.
class LanguageCatalog {
  static const List<Language> all = [
    Language(id: 'auto', nativeName: 'Auto', displayName: '自动检测', promptName: 'auto'),
    Language(id: 'zh', nativeName: '中文', displayName: '中文', promptName: '中文'),
    Language(id: 'en', nativeName: 'English', displayName: '英文', promptName: '英文'),
    Language(id: 'ja', nativeName: '日本語', displayName: '日文', promptName: '日文'),
    Language(id: 'ko', nativeName: '한국어', displayName: '韩文', promptName: '韩文'),
    Language(id: 'fr', nativeName: 'Français', displayName: '法文', promptName: '法文'),
    Language(id: 'de', nativeName: 'Deutsch', displayName: '德文', promptName: '德文'),
    Language(id: 'es', nativeName: 'Español', displayName: '西班牙文', promptName: '西班牙文'),
    Language(id: 'pt', nativeName: 'Português', displayName: '葡萄牙文', promptName: '葡萄牙文'),
    Language(id: 'ru', nativeName: 'Русский', displayName: '俄文', promptName: '俄文'),
    Language(id: 'it', nativeName: 'Italiano', displayName: '意大利文', promptName: '意大利文'),
    Language(id: 'ar', nativeName: 'العربية', displayName: '阿拉伯文', promptName: '阿拉伯文'),
    Language(id: 'th', nativeName: 'ไทย', displayName: '泰文', promptName: '泰文'),
    Language(id: 'vi', nativeName: 'Tiếng Việt', displayName: '越南文', promptName: '越南文'),
    Language(id: 'id', nativeName: 'Bahasa Indonesia', displayName: '印尼文', promptName: '印尼文'),
    Language(id: 'ms', nativeName: 'Bahasa Melayu', displayName: '马来文', promptName: '马来文'),
    Language(id: 'tr', nativeName: 'Türkçe', displayName: '土耳其文', promptName: '土耳其文'),
    Language(id: 'nl', nativeName: 'Nederlands', displayName: '荷兰文', promptName: '荷兰文'),
    Language(id: 'pl', nativeName: 'Polski', displayName: '波兰文', promptName: '波兰文'),
    Language(id: 'hi', nativeName: 'हिन्दी', displayName: '印地文', promptName: '印地文'),
  ];

  static List<Language> get targets =>
      all.where((l) => l.id != 'auto').toList(growable: false);

  static Language byId(String id) =>
      all.firstWhere((l) => l.id == id, orElse: () => all[1]);
}
