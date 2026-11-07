import Foundation

/// 生词本里的一条记录。整条解析结果一起存下来，方便离线回看。
struct VocabularyEntry: Codable, Identifiable, Hashable, Sendable {
    var id: UUID = UUID()
    var term: String
    var kind: AnalysisKind
    var result: AnalysisResult
    var createdAt: Date = Date()

    var phonetic: String {
        result.word?.phonetic ?? ""
    }

    var partOfSpeech: String {
        result.word?.partOfSpeech ?? ""
    }

    var summary: String {
        result.summaryText
    }
}
