import Foundation

/// 词库里的一条记录。整条解析结果一起存下来，方便离线回看。
///
/// 除了原始解析结果，还记了四样东西：
/// - `starred`：收藏（这句写得好，我想模仿）—— 和「学没学会」无关
/// - `mastered`：你确认「已经会了」
/// - `lessonText`：上次「讲深一点」的全文（存下来就不用再花一次钱）
/// - `lessonAt`：讲解生成的时间
/// - `lastReviewedAt` / `reviewCount`：复习时点过几次
///
/// 旧版本的 vocabulary.json 里没有这些键，所以自己写 `init(from:)`，
/// 缺字段时用默认值补齐，不会让整本词库解码失败。
struct VocabularyEntry: Codable, Identifiable, Hashable, Sendable {
    var id: UUID = UUID()
    var term: String = ""
    var kind: AnalysisKind = .word
    var result: AnalysisResult = AnalysisResult()
    var createdAt: Date = Date()

    var starred: Bool = false
    var mastered: Bool = false
    var lessonText: String? = nil
    var lessonAt: Date? = nil
    var lastReviewedAt: Date? = nil
    var reviewCount: Int = 0

    init(term: String, kind: AnalysisKind, result: AnalysisResult, createdAt: Date = Date()) {
        self.term = term
        self.kind = kind
        self.result = result
        self.createdAt = createdAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = container.decodeValue(.id, fallback: UUID())
        term = container.decodeValue(.term, fallback: "")
        kind = container.decodeValue(.kind, fallback: .word)
        result = container.decodeValue(.result, fallback: AnalysisResult())
        createdAt = container.decodeValue(.createdAt, fallback: Date())
        starred = container.decodeValue(.starred, fallback: false)
        mastered = container.decodeValue(.mastered, fallback: false)
        lessonText = container.decodeOptional(.lessonText)
        lessonAt = container.decodeOptional(.lessonAt)
        lastReviewedAt = container.decodeOptional(.lastReviewedAt)
        reviewCount = container.decodeValue(.reviewCount, fallback: 0)
    }

    var phonetic: String {
        result.word?.phonetic ?? ""
    }

    var partOfSpeech: String {
        result.word?.partOfSpeech ?? ""
    }

    var summary: String {
        result.summaryText
    }

    var hasLesson: Bool {
        !(lessonText ?? "").isEmpty
    }
}
