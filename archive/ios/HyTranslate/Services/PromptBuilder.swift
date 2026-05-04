import Foundation

/// Builds the exact prompt string fed to Hy-MT1.5.
///
/// Verified against tokenizer_config.json from AngelSlim/Hy-MT1.5-1.8B-2bit
/// (HuggingFace, fetched 2026-05). The Hy-MT1.5 vocab uses **full-width** pipe
/// characters in the special tokens (NOT ASCII):
///
///   <｜hy_begin▁of▁sentence｜>   id 120000  BOS
///   <｜hy_place▁holder▁no▁2｜>   id 120002  EOS  (tokenizer.eos_token)
///   <｜hy_User｜>                id 120006
///   <｜hy_Assistant｜>           id 120007
///   <｜hy_EOT｜>                 id 120008
///
/// Conversation format follows the Hunyuan instruct convention:
///
///   <BOS><｜hy_User｜>{user}<｜hy_Assistant｜>{assistant}<｜hy_EOT｜>
///
/// We emit prompt up to and including <｜hy_Assistant｜> and let the model
/// generate. Generation stops on EOS or <｜hy_EOT｜> (handled by llama.cpp's
/// `llama_vocab_is_eog`).
public enum PromptBuilder {

    // NOTE: full-width '｜' (U+FF5C), not ASCII '|' (U+007C).
    private static let bos       = "<｜hy_begin▁of▁sentence｜>"
    private static let userTok   = "<｜hy_User｜>"
    private static let assistTok = "<｜hy_Assistant｜>"

    public static func translation(source: Language, target: Language, text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let body: String
        if source.id == "auto" {
            body = "请将下面的文本翻译成\(target.promptName)，只输出译文，不要解释或添加其他内容。\n\n\(trimmed)"
        } else {
            body = "请将下面的\(source.promptName)文本翻译成\(target.promptName)，只输出译文，不要解释或添加其他内容。\n\n\(trimmed)"
        }
        return "\(bos)\(userTok)\(body)\(assistTok)"
    }
}
