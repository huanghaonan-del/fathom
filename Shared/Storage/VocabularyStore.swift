import Foundation
import Observation

/// 词库的汇总数字，给首页底部那行小字用。
struct LibraryStats: Equatable, Sendable {
    var total: Int = 0
    /// 还没标「已掌握」的句子数，也就是复习队列。
    var learning: Int = 0
    /// 收藏（星标）的条数。
    var favorites: Int = 0
    var mastered: Int = 0
    var weekAdded: Int = 0
    var repeated: Int = 0
}

/// 词库存储：一个 JSON 文件放在 App Group 容器里，App 与扩展各持一个实例。
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

    // MARK: - 读取

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

    func entry(withID id: UUID) -> VocabularyEntry? {
        entries.first { $0.id == id }
    }

    func entry(for result: AnalysisResult) -> VocabularyEntry? {
        let term = result.titleText
        return entries.first { $0.term == term && $0.kind == result.kind }
    }

    var stats: LibraryStats {
        let weekAgo = Date().addingTimeInterval(-7 * 24 * 60 * 60)
        var stats = LibraryStats()
        stats.total = entries.count
        stats.favorites = entries.filter(\.starred).count
        stats.mastered = entries.filter(\.mastered).count
        stats.learning = stats.total - stats.mastered
        stats.weekAdded = entries.filter { $0.createdAt >= weekAgo }.count

        var counts: [String: Int] = [:]
        for entry in entries {
            counts[entry.term.lowercased(), default: 0] += 1
        }
        stats.repeated = counts.values.filter { $0 > 1 }.count
        return stats
    }

    /// 还没掌握的句子，最久没复习的排前面——复习时先挑快忘的。
    func reviewQueue() -> [VocabularyEntry] {
        entries
            .filter { !$0.mastered }
            .sorted { lhs, rhs in
                let l = lhs.lastReviewedAt ?? lhs.createdAt
                let r = rhs.lastReviewedAt ?? rhs.createdAt
                return l < r
            }
    }

    /// 抽一组复习卡：优先「从没复习过 + 很久没看」的。
    func reviewBatch(limit: Int) -> [VocabularyEntry] {
        Array(reviewQueue().prefix(max(limit, 1)))
    }

    /// 收藏的句子，按时间倒序。
    var favorites: [VocabularyEntry] {
        entries.filter(\.starred)
    }

    /// 查得最多的几个词，给「本周复盘」用。
    func topTerms(limit: Int = 8) -> [(term: String, count: Int)] {
        var counts: [String: (display: String, count: Int)] = [:]
        for entry in entries {
            let key = entry.term.lowercased()
            if let existing = counts[key] {
                counts[key] = (existing.display, existing.count + 1)
            } else {
                counts[key] = (entry.term, 1)
            }
        }
        return counts.values
            .sorted { $0.count > $1.count }
            .prefix(limit)
            .map { (term: $0.display, count: $0.count) }
    }

    // MARK: - 写入

    @discardableResult
    func add(_ result: AnalysisResult) -> VocabularyEntry? {
        let term = result.titleText
        guard !term.isEmpty else { return nil }

        // 30 秒内重复点「重新解析」不要重复写词库。
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

    /// 收藏 / 取消收藏。这是「这句写得好」，和学没学会无关。
    func toggleStar(id: UUID) {
        update(id) { $0.starred.toggle() }
    }

    /// 标 / 取消「已掌握」。标记掌握时顺手取消收藏？不——收藏是另一个维度，保持独立。
    func toggleMastered(id: UUID) {
        update(id) { entry in
            entry.mastered.toggle()
            entry.lastReviewedAt = Date()
            entry.reviewCount += 1
        }
    }

    /// 复习时点「记住了」：标掌握。
    func markReviewed(id: UUID, mastered: Bool) {
        update(id) { entry in
            entry.lastReviewedAt = Date()
            entry.reviewCount += 1
            if mastered { entry.mastered = true }
        }
    }

    /// 把「讲深一点」的全文挂到对应记录上。找不到记录时先补一条。
    func saveLesson(_ text: String, for result: AnalysisResult) {
        let cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return }

        if let existing = entry(for: result) {
            update(existing.id) { entry in
                entry.lessonText = cleaned
                entry.lessonAt = Date()
            }
            return
        }

        if let created = add(result) {
            update(created.id) { entry in
                entry.lessonText = cleaned
                entry.lessonAt = Date()
            }
        }
    }

    // MARK: - 内部

    private func update(_ id: UUID, _ change: (inout VocabularyEntry) -> Void) {
        guard let index = entries.firstIndex(where: { $0.id == id }) else { return }
        change(&entries[index])
        persist()
    }

    private func persist() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(entries) else { return }
        try? data.write(to: fileURL, options: [.atomic])
    }
}
