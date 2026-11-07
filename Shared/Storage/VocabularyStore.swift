import Foundation
import Observation

/// 生词本存储：一个 JSON 文件放在 App Group 容器里，App 与扩展各持一个实例。
/// 数据量在几千条以内时，这种同步读写足够快，也便于你直接查看/备份文件。
@Observable
final class VocabularyStore {
    private(set) var entries: [VocabularyEntry] = []

    init() {
        reload()
    }

    var fileURL: URL {
        SharedStorage.dataDirectory.appendingPathComponent(AppConfig.vocabularyFileName)
    }

    func reload() {
        guard let data = try? Data(contentsOf: fileURL) else {
            entries = []
            return
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = (try? decoder.decode([VocabularyEntry].self, from: data)) ?? []
        entries = decoded.sorted { $0.createdAt > $1.createdAt }
    }

    @discardableResult
    func add(_ result: AnalysisResult) -> VocabularyEntry? {
        let term = result.titleText
        guard !term.isEmpty else { return nil }

        // 30 秒内重复点「重新解析」不要重复写生词本。
        if let first = entries.first,
           first.term == term,
           first.kind == result.kind,
           Date().timeIntervalSince(first.createdAt) < 30 {
            return first
        }

        let entry = VocabularyEntry(term: term, kind: result.kind, result: result)
        entries.insert(entry, at: 0)
        persist()
        return entry
    }

    func remove(id: UUID) {
        entries.removeAll { $0.id == id }
        persist()
    }

    func remove(ids: Set<UUID>) {
        entries.removeAll { ids.contains($0.id) }
        persist()
    }

    func removeAll() {
        entries.removeAll()
        persist()
    }

    func entry(withID id: UUID) -> VocabularyEntry? {
        entries.first { $0.id == id }
    }

    private func persist() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(entries) else { return }
        try? data.write(to: fileURL, options: [.atomic])
    }
}
