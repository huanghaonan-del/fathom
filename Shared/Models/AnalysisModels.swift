import Foundation

// MARK: - 解析类型

/// 用户选中的内容按单词/短语解析，还是按整句解析。
enum AnalysisKind: String, Codable, CaseIterable, Sendable {
    case word
    case sentence

    var displayName: String {
        switch self {
        case .word: return "单词"
        case .sentence: return "句子"
        }
    }

    var toggleTitle: String {
        switch self {
        case .word: return "单词 / 短语"
        case .sentence: return "整句"
        }
    }
}

// MARK: - 请求

struct AnalysisRequest: Sendable {
    let text: String
    let kind: AnalysisKind
    let sourceHint: String?

    init(text: String, kind: AnalysisKind, sourceHint: String? = nil) {
        self.text = text
        self.kind = kind
        self.sourceHint = sourceHint
    }
}

// MARK: - 容错解码工具

extension KeyedDecodingContainer {
    /// 字段缺失或类型不符时返回兜底值，避免模型少写一个字段就整条解析失败。
    func decodeValue<T: Decodable>(_ key: Key, fallback: T) -> T {
        (try? decodeIfPresent(T.self, forKey: key)) ?? fallback
    }

    func decodeOptional<T: Decodable>(_ key: Key) -> T? {
        try? decodeIfPresent(T.self, forKey: key)
    }
}

// MARK: - 单词解析结果

struct ExampleSentence: Codable, Hashable, Sendable {
    var en: String = ""
    var zh: String = ""

    enum CodingKeys: String, CodingKey {
        case en
        case zh
    }
}

extension ExampleSentence {
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        en = container.decodeValue(.en, fallback: "")
        zh = container.decodeValue(.zh, fallback: "")
    }
}

struct WordAnalysis: Codable, Hashable, Sendable {
    var headword: String = ""
    var phonetic: String = ""
    var partOfSpeech: String = ""
    var meanings: [String] = []
    var collocations: [String] = []
    var examples: [ExampleSentence] = []
    var nuance: String = ""
    var memoryHook: String = ""

    enum CodingKeys: String, CodingKey {
        case headword
        case phonetic
        case partOfSpeech
        case meanings
        case collocations
        case examples
        case nuance
        case memoryHook
    }
}

extension WordAnalysis {
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        headword = container.decodeValue(.headword, fallback: "")
        phonetic = container.decodeValue(.phonetic, fallback: "")
        partOfSpeech = container.decodeValue(.partOfSpeech, fallback: "")
        meanings = container.decodeValue(.meanings, fallback: [])
        collocations = container.decodeValue(.collocations, fallback: [])
        examples = container.decodeValue(.examples, fallback: [])
        nuance = container.decodeValue(.nuance, fallback: "")
        memoryHook = container.decodeValue(.memoryHook, fallback: "")
    }
}

// MARK: - 句子解析结果

struct StructureItem: Codable, Hashable, Sendable {
    var role: String = ""
    var text: String = ""
    var note: String = ""

    enum CodingKeys: String, CodingKey {
        case role
        case text
        case note
    }
}

extension StructureItem {
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        role = container.decodeValue(.role, fallback: "")
        text = container.decodeValue(.text, fallback: "")
        note = container.decodeValue(.note, fallback: "")
    }
}

struct ClauseItem: Codable, Hashable, Sendable {
    var type: String = ""
    var text: String = ""
    var note: String = ""

    enum CodingKeys: String, CodingKey {
        case type
        case text
        case note
    }
}

extension ClauseItem {
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        type = container.decodeValue(.type, fallback: "")
        text = container.decodeValue(.text, fallback: "")
        note = container.decodeValue(.note, fallback: "")
    }
}

struct KeyVocabulary: Codable, Hashable, Sendable {
    var word: String = ""
    var meaning: String = ""
    var note: String = ""

    enum CodingKeys: String, CodingKey {
        case word
        case meaning
        case note
    }
}

extension KeyVocabulary {
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        word = container.decodeValue(.word, fallback: "")
        meaning = container.decodeValue(.meaning, fallback: "")
        note = container.decodeValue(.note, fallback: "")
    }
}

/// 语块 / 地道表达：母语者会整体记下来、而不是逐词翻译的片段。
struct ChunkItem: Codable, Hashable, Sendable {
    /// 英文原文片段，例如 "reach a consensus"
    var text: String = ""
    /// 中文意思（在句中这个语境下的意思）
    var meaning: String = ""
    /// 类别：搭配 / 习语 / 口语 / 固定说法 / 语篇连接
    var kind: String = ""
    /// 为什么母语者这么说（语感、语气、能不能替换）
    var note: String = ""

    enum CodingKeys: String, CodingKey {
        case text
        case meaning
        case kind
        case note
    }
}

extension ChunkItem {
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        text = container.decodeValue(.text, fallback: "")
        meaning = container.decodeValue(.meaning, fallback: "")
        kind = container.decodeValue(.kind, fallback: "")
        note = container.decodeValue(.note, fallback: "")
    }
}

struct SentenceAnalysis: Codable, Hashable, Sendable {
    var translation: String = ""    /// 母语者读到这句时的第一反应：口气、态度、隐含意思
    var nativeTake: String = ""
    /// 语块与地道表达
    var chunks: [ChunkItem] = []
    var structure: [StructureItem] = []
    var clauses: [ClauseItem] = []
    var keyVocabulary: [KeyVocabulary] = []
    var grammarNotes: [String] = []
    var difficulty: String = ""

    enum CodingKeys: String, CodingKey {
        case translation
        case nativeTake
        case chunks
        case structure
        case clauses
        case keyVocabulary
        case grammarNotes
        case difficulty
    }
}

extension SentenceAnalysis {
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        translation = container.decodeValue(.translation, fallback: "")
        nativeTake = container.decodeValue(.nativeTake, fallback: "")
        chunks = container.decodeValue(.chunks, fallback: [])
        structure = container.decodeValue(.structure, fallback: [])
        clauses = container.decodeValue(.clauses, fallback: [])
        keyVocabulary = container.decodeValue(.keyVocabulary, fallback: [])
        grammarNotes = container.decodeValue(.grammarNotes, fallback: [])
        difficulty = container.decodeValue(.difficulty, fallback: "")
    }
}

// MARK: - 模型原始输出

/// 模型返回的 JSON 顶层结构。
struct AnalysisPayload: Decodable, Sendable {
    var kind: AnalysisKind?
    var word: WordAnalysis?
    var sentence: SentenceAnalysis?

    enum CodingKeys: String, CodingKey {
        case kind
        case word
        case sentence
    }
}

extension AnalysisPayload {
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        kind = container.decodeOptional(.kind)
        word = container.decodeOptional(.word)
        sentence = container.decodeOptional(.sentence)
    }
}

// MARK: - 最终结果

struct AnalysisResult: Codable, Identifiable, Hashable, Sendable {
    var id: UUID = UUID()
    var original: String = ""
    var kind: AnalysisKind = .sentence
    var word: WordAnalysis?
    var sentence: SentenceAnalysis?
    var engine: String = ""
    var createdAt: Date = Date()
}

extension AnalysisResult {
    var titleText: String {
        if let headword = word?.headword, !headword.isEmpty {
            return headword
        }
        return original
    }

    var summaryText: String {
        if let sentence, !sentence.translation.isEmpty {
            return sentence.translation
        }
        if let word, let first = word.meanings.first {
            return first
        }
        return ""
    }

    var searchableText: String {
        var parts: [String] = [original, engine]
        if let word {
            parts.append(contentsOf: word.meanings)
            parts.append(contentsOf: word.collocations)
            parts.append(word.nuance)
        }
        if let sentence {
            parts.append(sentence.translation)
            parts.append(sentence.nativeTake)
            parts.append(contentsOf: sentence.chunks.map { item in "\(item.text) \(item.meaning) \(item.note)" })
            parts.append(contentsOf: sentence.grammarNotes)
        }
        return parts.joined(separator: " ")
    }

    /// 用于「一键复制」的纯文本版本。
    var plainText: String {
        var lines: [String] = []
        lines.append("【原文】\(original)")

        if let word {
            if !word.phonetic.isEmpty { lines.append("音标：\(word.phonetic)") }
            if !word.partOfSpeech.isEmpty { lines.append("词性：\(word.partOfSpeech)") }
            if !word.meanings.isEmpty {
                lines.append("释义：\n" + word.meanings.map { "· \($0)" }.joined(separator: "\n"))
            }
            if !word.collocations.isEmpty {
                lines.append("常见搭配：\n" + word.collocations.map { "· \($0)" }.joined(separator: "\n"))
            }
            if !word.examples.isEmpty {
                let examples = word.examples.map { example -> String in
                    let zh = example.zh.isEmpty ? "" : "\n  \(example.zh)"
                    return "· \(example.en)\(zh)"
                }
                lines.append("例句：\n" + examples.joined(separator: "\n"))
            }
            if !word.nuance.isEmpty { lines.append("语义辨析：\(word.nuance)") }
            if !word.memoryHook.isEmpty { lines.append("记忆钩子：\(word.memoryHook)") }
        }

        if let sentence {
            if !sentence.translation.isEmpty { lines.append("译文：\(sentence.translation)") }
            if !sentence.nativeTake.isEmpty { lines.append("母语者视角：\(sentence.nativeTake)") }
            if !sentence.chunks.isEmpty {
                let chunks = sentence.chunks.map { item -> String in
                    let kind = item.kind.isEmpty ? "" : "【\(item.kind)】"
                    let note = item.note.isEmpty ? "" : "\n  \(item.note)"
                    return "· \(kind)\(item.text) — \(item.meaning)\(note)"
                }
                lines.append("语块与地道表达：\n" + chunks.joined(separator: "\n"))
            }
            if !sentence.structure.isEmpty {
                let structure = sentence.structure.map { item -> String in
                    let note = item.note.isEmpty ? "" : "（\(item.note)）"
                    return "· \(item.role)：\(item.text)\(note)"
                }
                lines.append("句子结构：\n" + structure.joined(separator: "\n"))
            }
            if !sentence.clauses.isEmpty {
                let clauses = sentence.clauses.map { item -> String in
                    let note = item.note.isEmpty ? "" : "（\(item.note)）"
                    return "· \(item.type)：\(item.text)\(note)"
                }
                lines.append("从句拆解：\n" + clauses.joined(separator: "\n"))
            }
            if !sentence.keyVocabulary.isEmpty {
                let vocabulary = sentence.keyVocabulary.map { item -> String in
                    let note = item.note.isEmpty ? "" : " \(item.note)"
                    return "· \(item.word)：\(item.meaning)\(note)"
                }
                lines.append("难点词汇：\n" + vocabulary.joined(separator: "\n"))
            }
            if !sentence.grammarNotes.isEmpty {
                lines.append("语法点：\n" + sentence.grammarNotes.map { "· \($0)" }.joined(separator: "\n"))
            }
        }

        lines.append("—— 由 \(engine) 生成")
        return lines.joined(separator: "\n\n")
    }
}

// MARK: - 错误

enum AnalysisError: LocalizedError, Sendable {
    case emptyInput
    case missingAPIKey
    case invalidConfiguration(String)
    case network(String)
    case server(status: Int, message: String)
    case emptyResponse
    case malformedResponse(String)
    case cancelled

    var errorDescription: String? {
        switch self {
        case .emptyInput:
            return "没有收到可解析的文字。"
        case .missingAPIKey:
            return "还没有填写 API Key。点底部的「设置」→ 粘贴 Key → 点「测试连接」。\nDeepSeek 的 Key 在 platform.deepseek.com → API keys 创建，以 sk- 开头。"
        case .invalidConfiguration(let message):
            return message
        case .network(let message):
            return "网络请求失败：\(message)"
        case .server(let status, let message):
            if status == 401 || status == 403 {
                return "鉴权失败（HTTP \(status)）：API Key 可能填错、过期或没有权限。\n\(message)"
            }
            if status == 429 {
                return "请求太频繁或额度用完了（HTTP 429）。稍后再试，或检查账户余额。\n\(message)"
            }
            if status == 402 {
                return "账户余额不足（HTTP 402）。请到服务商后台充值后再试（DeepSeek 在 platform.deepseek.com → 充值）。\n\(message)"
            }
            if status == 400 {
                return "请求被拒绝（HTTP 400）：最常见的原因是设置里的模型名写错了。DeepSeek 请填 deepseek-flash 或 deepseek-v4-pro。\n\(message)"
            }
            return "服务返回错误（HTTP \(status)）：\(message)"
        case .emptyResponse:
            return "服务返回了空内容，请重试。"
        case .malformedResponse(let message):
            return "解析结果格式不正确：\(message)"
        case .cancelled:
            return "请求已取消。"
        }
    }
}

// MARK: - 深度讲解（「讲深一点」）

/// 讲解里的一小块内容。用固定的几种 kind，界面就不需要解析 Markdown。
struct LessonBlock: Codable, Hashable, Sendable {
    /// h2 / p / step / bullet / example / rowhead / row
    var kind: String = "p"
    /// 主要内容：h2 与 p 是中文；step 与 row 的 text 是英文片段；example 的 text 是英文例句
    var text: String = ""
    /// 中文补充：bullet 的中文意思、example 的中文翻译、row 的第二列
    var zh: String = ""
    /// row 的第三列（中文意思）
    var note: String = ""

    enum CodingKeys: String, CodingKey {
        case kind
        case text
        case zh
        case note
    }
}

extension LessonBlock {
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        kind = container.decodeValue(.kind, fallback: "p")
        text = container.decodeValue(.text, fallback: "")
        zh = container.decodeValue(.zh, fallback: "")
        note = container.decodeValue(.note, fallback: "")
    }
}

/// 有些模型会把结果包一层 `{"lesson": {...}}`，两种写法都接受。
struct LessonEnvelope: Codable, Sendable {
    var lesson: Lesson?
}

/// 「讲深一点」返回的一整节课。
struct Lesson: Codable, Hashable, Sendable {
    var title: String = ""
    var blocks: [LessonBlock] = []

    enum CodingKeys: String, CodingKey {
        case title
        case blocks
    }
}

extension Lesson {
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        title = container.decodeValue(.title, fallback: "")
        blocks = container.decodeValue(.blocks, fallback: [LessonBlock]())
    }

    /// 复制到剪贴板用的纯文本。
    var plainText: String {
        var lines: [String] = []
        if !title.isEmpty { lines.append(title) }
        for block in blocks {
            switch block.kind {
            case "h2":
                lines.append("")
                lines.append("【\(block.text)】")
            case "step":
                lines.append("")
                lines.append(block.text + (block.zh.isEmpty ? "" : "（\(block.zh)）"))
            case "bullet":
                lines.append("· \(block.text)" + (block.zh.isEmpty ? "" : " —— \(block.zh)"))
            case "example":
                lines.append("  例：" + block.text)
                if !block.zh.isEmpty { lines.append("        \(block.zh)") }
            case "rowhead":
                lines.append("  英语部分 | 作用 | 中文意思")
            case "row":
                lines.append("  \(block.text) | \(block.zh) | \(block.note)")
            default:
                lines.append(block.text)
            }
        }
        return lines.joined(separator: "\n")
    }
}

