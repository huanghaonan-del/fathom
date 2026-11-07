import Foundation

enum TextNormalizer {
    static var maxLength: Int { AppConfig.maxInputLength }

    /// 复制过来的文本常带换行、制表符、不换行空格，统一压成单行。
    static func normalize(_ raw: String) -> String {
        var text = raw
        text = text.replacingOccurrences(of: "\u{00A0}", with: " ")
        text = text.replacingOccurrences(of: "\r\n", with: "\n")
        text = text.replacingOccurrences(of: "\r", with: "\n")
        text = text.replacingOccurrences(of: "\t", with: " ")

        let collapsed = text
            .split(whereSeparator: { $0.isWhitespace })
            .joined(separator: " ")

        var result = collapsed.trimmingCharacters(in: .whitespacesAndNewlines)
        if result.count > maxLength {
            result = String(result.prefix(maxLength)) + "…"
        }
        return result
    }

    /// 没选类型时自动判断：单个词、少量词且没有句末标点 → 按单词处理。
    static func guessKind(_ text: String) -> AnalysisKind {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .sentence }

        let words = trimmed.split(whereSeparator: { $0.isWhitespace })
        if words.count == 1 { return .word }

        let terminal: Set<Character> = [".", "!", "?", "。", "！", "？", ";", "；", ":"]
        let endsWithTerminal = trimmed.last.map { terminal.contains($0) } ?? false
        if words.count <= 3 && !endsWithTerminal { return .word }
        return .sentence
    }

    /// 去掉用户连标点一起选中的情况，例如 “ephemeral,”。
    static func stripWordPunctuation(_ text: String) -> String {
        text.trimmingCharacters(in: CharacterSet.punctuationCharacters.union(.whitespacesAndNewlines))
    }

    /// 有些 App（X、Instagram 等）分享时只给一条链接，那不是可解析的文本。
    static func isBareLink(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("http://") || trimmed.hasPrefix("https://") else { return false }
        return !trimmed.contains(where: { $0.isWhitespace })
    }
}
