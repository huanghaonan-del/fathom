import SwiftUI
import UIKit

/// 「本周复盘」：完全在本地算，不花 API 的钱，也不联网。
///
/// 目的不是给你好看的数字，而是回答三个问题：
/// 这一周我到底在查什么？哪些是真记住的？下一步该复习什么？
struct LibraryReviewView: View {
    let store: VocabularyStore

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    overviewCard
                    topTermsCard
                    statusCard
                    suggestionCard
                    Text("按目前的数据本地统计，不消耗 API 额度。")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                .padding(16)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("本周复盘")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("关闭") { dismiss() }
                }
            }
        }
    }

    // MARK: - 卡片

    private var overviewCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("这一周")
                .font(.subheadline.weight(.semibold))
            HStack(alignment: .top, spacing: 0) {
                bigNumber("\(weekAdded)", "本周新增", tint: .accentColor)
                bigNumber("\(lastWeekAdded)", "上周同期", tint: .secondary)
                bigNumber("\(streak)", "连续天数", tint: .orange)
            }
            Divider()
            HStack {
                Label("\(wordCount) 个词", systemImage: "textformat.abc")
                Spacer()
                Label("\(sentenceCount) 个句子", systemImage: "text.alignleft")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var topTermsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("查得最多的")
                .font(.subheadline.weight(.semibold))

            if topTerms.isEmpty {
                Text("还没有记录。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(Array(topTerms.enumerated()), id: \.offset) { item in
                    HStack(spacing: 10) {
                        Text("\(item.offset + 1)")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.tertiary)
                            .frame(width: 16, alignment: .leading)
                        Text(item.element.term)
                            .font(.callout)
                            .lineLimit(1)
                        Spacer(minLength: 8)
                        Text("\(item.element.count) 次")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                }
                if repeatedCount > 0 {
                    Text("有 \(repeatedCount) 个词你查了不止一遍——这类最值得进复习。")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .padding(.top, 2)
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var statusCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("掌握情况")
                .font(.subheadline.weight(.semibold))
            progressRow(title: "已掌握", value: masteredCount, total: totalCount, tint: .green)
            progressRow(title: "重点（还要看）", value: starredCount, total: totalCount, tint: .orange)
            progressRow(title: "待学", value: max(totalCount - masteredCount, 0), total: totalCount, tint: .accentColor)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var suggestionCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("下周可以这样", systemImage: "lightbulb")
                .font(.subheadline.weight(.semibold))
            Text(suggestion)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.accentColor.opacity(0.08), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    // MARK: - 小部件

    private func bigNumber(_ value: String, _ title: String, tint: Color) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.title2.weight(.semibold))
                .foregroundStyle(tint)
                .monospacedDigit()
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func progressRow(title: String, value: Int, total: Int, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                    .font(.caption)
                Spacer()
                Text("\(value)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            GeometryReader { proxy in
                let ratio = total > 0 ? min(max(Double(value) / Double(total), 0), 1) : 0
                ZStack(alignment: .leading) {
                    Capsule().fill(Color(uiColor: .tertiarySystemFill))
                    Capsule()
                        .fill(tint.opacity(0.85))
                        .frame(width: proxy.size.width * ratio)
                }
            }
            .frame(height: 6)
        }
    }

    // MARK: - 计算

    private var weekAdded: Int {
        store.entries.filter { $0.createdAt >= weekStart }.count
    }

    private var lastWeekAdded: Int {
        store.entries.filter { $0.createdAt >= lastWeekStart && $0.createdAt < weekStart }.count
    }

    private var weekStart: Date {
        Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
    }

    private var lastWeekStart: Date {
        Calendar.current.date(byAdding: .day, value: -14, to: Date()) ?? Date()
    }

    private var wordCount: Int { store.entries.filter { $0.kind == .word }.count }
    private var sentenceCount: Int { store.entries.filter { $0.kind == .sentence }.count }
    private var totalCount: Int { store.entries.count }
    private var starredCount: Int { store.entries.filter(\.starred).count }
    private var masteredCount: Int { store.entries.filter(\.mastered).count }
    private var repeatedCount: Int {
        store.topTerms(limit: 100).filter { $0.count > 1 }.count
    }
    private var topTerms: [(term: String, count: Int)] {
        store.topTerms(limit: 6)
    }

    /// 连续查询天数：从今天往前数，连着有记录的天数。
    private var streak: Int {
        let calendar = Calendar.current
        let days = Set(store.entries.map { calendar.startOfDay(for: $0.createdAt) })
        guard !days.isEmpty else { return 0 }
        var cursor = calendar.startOfDay(for: Date())
        if !days.contains(cursor) {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: cursor) else { return 0 }
            cursor = yesterday
            guard days.contains(cursor) else { return 0 }
        }
        var count = 0
        while days.contains(cursor) {
            count += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = previous
        }
        return count
    }

    private var suggestion: String {
        if totalCount == 0 {
            return "先查几个词。等你有一周的记录，这里会告诉你该复习什么。"
        }
        if starredCount > 0 {
            return "你有 \(starredCount) 个词标了重点还没标「已掌握」。建议每天挑 5 个，用「重点」筛选复习一遍，会的划掉。"
        }
        if repeatedCount > 0 {
            return "有 \(repeatedCount) 个词你查了不止一次。把它们标成重点，下次复习优先看这些——查了两遍说明第一遍没记住。"
        }
        if masteredCount == 0 {
            return "你还没标过「已掌握」。复习完一个词，右滑列表把它划掉，进度才看得出来。"
        }
        return "节奏不错。保持每天 5–10 个，比一次查 50 个有用。"
    }
}
