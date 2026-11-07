import SwiftUI
import UIKit

enum ExportFormat: String, Identifiable, CaseIterable {
    case csv
    case anki

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .csv: return "CSV 表格"
        case .anki: return "Anki 卡片"
        }
    }

    var fileExtension: String {
        switch self {
        case .csv: return "csv"
        case .anki: return "txt"
        }
    }

    var hint: String {
        switch self {
        case .csv: return "可用 Excel、Numbers、WPS 打开，也能导入 Notion。"
        case .anki: return "在 Anki 里「导入文件」，字段分隔符选 Tab 即可生成卡片。"
        }
    }
}

enum ExportService {
    /// 生成到临时目录，返回可直接分享的文件 URL。
    static func makeFile(entries: [VocabularyEntry], format: ExportFormat) throws -> URL {
        let stamp = ISO8601DateFormatter().string(from: Date()).prefix(10)
        let fileName = "Fathom-\(stamp).\(format.fileExtension)"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)

        let content: String
        switch format {
        case .csv:
            content = csv(entries)
        case .anki:
            content = anki(entries)
        }

        // 只有 CSV 需要 BOM：Excel 靠它判断 UTF-8，否则中文乱码。
        // Anki 文件首行必须是 #separator:tab，加了 BOM 会让首行失效，所以不加。
        let payload = format == .csv ? "\u{FEFF}" + content : content
        let data = payload.data(using: .utf8) ?? Data()
        try data.write(to: url, options: [.atomic])
        return url
    }

    // MARK: - CSV

    private static func csv(_ entries: [VocabularyEntry]) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]

        var rows: [String] = []
        rows.append(["单词", "类型", "音标", "词性", "中文释义", "例句", "查询时间"].map(escapeCSV).joined(separator: ","))

        for entry in entries {
            let word = entry.result.word
            let meanings = word?.meanings.joined(separator: " / ") ?? entry.result.sentence?.translation ?? ""
            let examples = word?.examples
                .filter { !$0.en.isEmpty }
                .map { $0.zh.isEmpty ? $0.en : "\($0.en) — \($0.zh)" }
                .joined(separator: " | ") ?? ""
            let fields = [
                entry.term,
                entry.kind.displayName,
                entry.phonetic,
                entry.partOfSpeech,
                meanings,
                examples,
                formatter.string(from: entry.createdAt)
            ]
            rows.append(fields.map(escapeCSV).joined(separator: ","))
        }

        return rows.joined(separator: "\r\n") + "\r\n"
    }

    private static func escapeCSV(_ value: String) -> String {
        let cleaned = value.replacingOccurrences(of: "\r\n", with: " ").replacingOccurrences(of: "\n", with: " ")
        if cleaned.contains(",") || cleaned.contains("\"") || cleaned.contains(";") {
            return "\"" + cleaned.replacingOccurrences(of: "\"", with: "\"\"") + "\""
        }
        return cleaned
    }

    // MARK: - Anki

    private static func anki(_ entries: [VocabularyEntry]) -> String {
        var rows: [String] = []
        // 首行是 Anki 的注释（以 # 开头会被忽略）。
        rows.append("#separator:tab")
        rows.append("#html:true")
        rows.append("#tags column:3")

        for entry in entries {
            let front = ankiFront(entry)
            let back = ankiBack(entry)
            let tags = "fathom " + (entry.kind == .word ? "word" : "sentence")
            rows.append([front, back, tags].joined(separator: "\t"))
        }
        return rows.joined(separator: "\n") + "\n"
    }

    private static func ankiFront(_ entry: VocabularyEntry) -> String {
        var parts = ["<b>\(html(entry.term))</b>"]
        if !entry.phonetic.isEmpty {
            parts.append("<i>\(html(entry.phonetic))</i>")
        }
        if !entry.partOfSpeech.isEmpty {
            parts.append("<span style=\"color:#888\">\(html(entry.partOfSpeech))</span>")
        }
        return parts.joined(separator: " ")
    }

    private static func ankiBack(_ entry: VocabularyEntry) -> String {
        var blocks: [String] = []

        if let word = entry.result.word {
            if !word.meanings.isEmpty {
                // 注意：先逐条转义，再用 <br> 连接。反过来会把 <br> 自己转义成 &lt;br&gt;，
                // 在 Anki 里就会原样显示这五个字符。
                let list = word.meanings.enumerated()
                    .map { "\($0.offset + 1). \(html($0.element))" }
                    .joined(separator: "<br>")
                blocks.append(list)
            }
            if !word.collocations.isEmpty {
                blocks.append("<b>搭配</b><br>" + html(word.collocations.prefix(4).joined(separator: "；")))
            }
            if let first = word.examples.first {
                let zh = first.zh.isEmpty ? "" : "<br>" + html(first.zh)
                blocks.append("<b>例</b><br>" + html(first.en) + zh)
            }
        } else if let sentence = entry.result.sentence {
            if !sentence.translation.isEmpty {
                blocks.append(html(sentence.translation))
            }
            if !sentence.keyVocabulary.isEmpty {
                let vocabulary = sentence.keyVocabulary
                    .map { "\(html($0.word))：\(html($0.meaning))" }
                    .joined(separator: "<br>")
                blocks.append("<b>难点词</b><br>" + vocabulary)
            }
        }

        return blocks.joined(separator: "<br><br>")
    }

    /// 转义成 Anki 的 HTML 字段内容：既要挡住标记，也要把换行/制表符处理掉，
    /// 否则一个 Tab 会把这一行拆成多列，卡片直接错位。
    private static func html(_ text: String) -> String {
        text
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .replacingOccurrences(of: "\t", with: " ")
            .replacingOccurrences(of: "\n", with: "<br>")
    }
}

/// 分享文件的 UIActivityViewController 包装。
struct ActivityView: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

/// 用 sheet 呈现分享面板。
struct ShareFileSheet: View {
    let url: URL

    var body: some View {
        ActivityView(items: [url])
            .presentationDetents([.medium, .large])
    }
}
