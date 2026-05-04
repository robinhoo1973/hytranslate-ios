import 'language.dart';

/// Builds the exact prompt fed to Hy-MT1.5.
///
/// Verified against tokenizer_config.json from AngelSlim/Hy-MT1.5-1.8B
/// (HuggingFace, fetched 2026-05). Hy-MT1.5 special tokens use **full-width**
/// pipe characters (U+FF5C ｜), not ASCII '|'.
///
///   <｜hy_begin▁of▁sentence｜>   id 120000  BOS
///   <｜hy_User｜>                id 120006
///   <｜hy_Assistant｜>           id 120007
///   <｜hy_EOT｜>                 id 120008
class PromptBuilder {
  static const String _bos = '<｜hy_begin▁of▁sentence｜>';
  static const String _userTok = '<｜hy_User｜>';
  static const String _assistTok = '<｜hy_Assistant｜>';

  static String translation({
    required Language source,
    required Language target,
    required String text,
  }) {
    final trimmed = text.trim();
    final body = source.id == 'auto'
        ? '请将下面的文本翻译成${target.promptName}，只输出译文，不要解释或添加其他内容。\n\n$trimmed'
        : '请将下面的${source.promptName}文本翻译成${target.promptName}，只输出译文，不要解释或添加其他内容。\n\n$trimmed';
    return '$_bos$_userTok$body$_assistTok';
  }
}
