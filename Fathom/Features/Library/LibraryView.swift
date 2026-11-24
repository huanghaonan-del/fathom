import SwiftUI
import UIKit

/// 首页「库」：一屏只有一件事——开始复习。
///
/// 列表按天分组，每行是一张「句子卡」。所有管理动作都收进滑动和菜单，
/// 不在主界面摆一排筛选按钮。
struct LibraryView: View {
    let store: VocabularyStore
    /// 剪贴板里是普通文字时，交给上一层去开解析页。
    var onAnalyzeText: (String) -> Void = { _ in }

    @State private var searchText = ""
    @State private var filter: Filter = .all
    @State private var showReview = false
    @State private var showReviewSummary = false
    @State private var showQuickInput = false
    @State private var showPasteHint = false
    @State private var exportFile: ExportPayload?
    @State private var confirmClear = false

    enum Filter: String, CaseIterable, Identifiable {
        case all, due, favorites
        var id: String { rawValue }
        var title: String {
            switch self {
            case .all: return "全部"
            case .due: return "待复习"
            case .favorites: return "收藏"
            }
        }
    }

    var body: some View {
        NavigationStack {
            mainList
                .listStyle(.insetGrouped)
                .navigationTitle("库")
                .searchable(
                    text: $searchText,
                    placement: .navigationBarDrawer(displayMode: .always),
                    prompt: "搜句子、译文、单词"
                )
                .toolbar { toolbarItems }
                .sheet(isPresented: $showReview, onDismiss: { store.reload() }) {
                    ReviewSessionView(store: store, limit: AppSettings.reviewBatchSize)
                }
                .sheet(isPresented: $showReviewSummary) {
                    LibraryReviewView(store: store)
                }
                .sheet(isPresented: $showQuickInput, onDismiss: { store.reload() }) {
                    QuickInputView(store: store)
                }
                .sheet(item: $exportFile) { payload in
                    ShareFileSheet(url: payload.url)
                }
                .alert("已复制，打开 Fathom 就能存", isPresented: $showPasteHint) {
                    Button("好", role: .cancel) {}
                } message: {
                    Text("从扩展复制的内容已经在剪贴板里，回到 App 会自动识别。")
                }
                .confirmationDialog(
                    "清空全部记录？",
                    isPresented: $confirmClear,
                    titleVisibility: .visible
                ) {
                    Button("清空", role: .destructive) { store.removeAll() }
                    Button("取消", role: .cancel) {}
                } message: {
                    Text("这会删掉所有句子卡和讲解，无法恢复。建议先导出 CSV 备份。")
                }
        }
    }

    // MARK: - 列表主体

    private var mainList: some View {
        List {
            headerSection
            contentSections
        }
    }

    private var headerSection: some View {
        Section {
            headerCard
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
        }
    }

    @ViewBuilder
    private var contentSections: some View {
        if groups.isEmpty {
            Section {
                emptyState
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            }
        } else {
            ForEach(groups) { group in
                Section {
                    ForEach(group.entries) { entry in
                        EntryRow(entry: entry, store: store)
                    }
                } header: {
                    groupHeader(group)
                }
            }
        }
    }

    private func groupHeader(_ group: DayGroup) -> some View {
        HStack {
            Text(group.title)
            Spacer()
            Text("\(group.entries.count)")
                .foregroundStyle(.tertiary)
        }
    }

    // MARK: - 工具栏

    @ToolbarContentBuilder
    private var toolbarItems: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            clipboardButton
        }
        ToolbarItem(placement: .topBarTrailing) {
            moreMenu
        }
    }

    private var clipboardButton: some View {
        Button {
            pasteFromClipboard()
        } label: {
            Image(systemName: "doc.on.clipboard")
        }
        .accessibilityLabel("解析剪贴板")
    }

    private var moreMenu: some View {
        Menu {
            filterPicker
            Divider()
            Button {
                showQuickInput = true
            } label: {
                Label("手动输入一段", systemImage: "square.and.pencil")
            }
            Button {
                showReviewSummary = true
            } label: {
                Label("本周复盘", systemImage: "chart.bar")
            }
            Divider()
            Button {
                export(.csv)
            } label: {
                Label("导出 CSV", systemImage: "tablecells")
            }
            Button {
                export(.anki)
            } label: {
                Label("导出 Anki", systemImage: "rectangle.stack")
            }
            Divider()
            Button(role: .destructive) {
                confirmClear = true
            } label: {
                Label("清空全部", systemImage: "trash")
            }
        } label: {
            Image(systemName: "ellipsis.circle")
        }
        .accessibilityLabel("更多")
    }

    private var filterPicker: some View {
        Picker("显示", selection: $filter) {
            ForEach(Filter.allCases) { item in
                Text(item.title).tag(item)
            }
        }
    }

    // MARK: - 顶部卡片

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(headline)
                .font(.headline)
                .foregroundStyle(dueCount > 0 ? Color.primary : Color.secondary)

            Button {
                showReview = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "play.fill")
                        .font(.footnote.weight(.bold))
                    Text(dueCount > 0 ? "开始复习" : "随便看看")
                        .font(.subheadline.weight(.semibold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    Color.accentColor,
                    in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                )
                .foregroundStyle(Color.white)
            }
            .buttonStyle(.plain)
            .disabled(store.entries.isEmpty)

            countsRow
        }
        .padding(16)
        .background(
            Color(uiColor: .secondarySystemGroupedBackground),
            in: RoundedRectangle(cornerRadius: 18, style: .continuous)
        )
    }

    private var headline: String {
        dueCount > 0 ? "今天还有 \(dueCount) 张没看" : "今天没有要复习的"
    }

    private var countsRow: some View {
        HStack(spacing: 14) {
            Text("收藏 \(stats.favorites)")
            Text("已掌握 \(stats.mastered)")
            Text("共 \(stats.total)")
            Spacer()
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .monospacedDigit()
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "text.book.closed")
                .font(.largeTitle)
                .foregroundStyle(.tertiary)
            Text(isLibraryEmpty ? "还没有句子卡" : "这里没有匹配的")
                .font(.subheadline.weight(.medium))
            Text(isLibraryEmpty
                 ? "在 Books、Safari 里长按选中一段英文 → 分享 → Fathom，它就会出现在这里。"
                 : "换个关键词或换个显示范围试试。")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    // MARK: - 数据

    private var stats: LibraryStats { store.stats }
    private var dueCount: Int { stats.learning }
    private var isLibraryEmpty: Bool { searchText.isEmpty && filter == .all }

    private var filteredEntries: [VocabularyEntry] {
        var list = store.entries
        switch filter {
        case .all: break
        case .due: list = list.filter { !$0.mastered }
        case .favorites: list = list.filter(\.starred)
        }
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return list }
        return list.filter { entry in
            entry.result.original.localizedCaseInsensitiveContains(query)
                || entry.term.localizedCaseInsensitiveContains(query)
                || entry.result.searchableText.localizedCaseInsensitiveContains(query)
        }
    }

    private var groups: [DayGroup] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: filteredEntries) {
            calendar.startOfDay(for: $0.createdAt)
        }
        let mapped = grouped.map { key, value in
            DayGroup(
                id: key,
                title: dayTitle(key),
                entries: value.sorted { $0.createdAt > $1.createdAt }
            )
        }
        return mapped.sorted { $0.id > $1.id }
    }

    private func dayTitle(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return "今天" }
        if calendar.isDateInYesterday(date) { return "昨天" }
        return date.formatted(.dateTime.month().day().weekday(.abbreviated))
    }

    // MARK: - 动作

    private func pasteFromClipboard() {
        guard let text = UIPasteboard.general.string, !text.isEmpty else { return }
        if let result = DeepLinkCodec.result(fromPastedText: text) {
            _ = store.add(result)
            return
        }
        onAnalyzeText(text)
    }

    private func export(_ format: ExportFormat) {
        guard let url = try? ExportService.makeFile(entries: store.entries, format: format) else {
            return
        }
        exportFile = ExportPayload(url: url)
    }
}

// MARK: - 一行

private struct EntryRow: View {
    let entry: VocabularyEntry
    let store: VocabularyStore

    var body: some View {
        NavigationLink {
            CardDetailView(store: store, entryID: entry.id)
        } label: {
            label
        }
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            starButton
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            deleteButton
            masteredButton
        }
    }

    private var label: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(displayOriginal)
                .font(.callout)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
            if !entry.summary.isEmpty {
                Text(entry.summary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 4)
        .overlay(alignment: .trailing) {
            badges
        }
    }

    private var badges: some View {
        HStack(spacing: 6) {
            if entry.starred {
                Image(systemName: "star.fill")
                    .font(.caption2)
                    .foregroundStyle(.orange)
            }
            if entry.mastered {
                Image(systemName: "checkmark.circle.fill")
                    .font(.caption2)
                    .foregroundStyle(.green)
            }
        }
        .padding(.leading, 8)
    }

    private var starButton: some View {
        Button {
            store.toggleStar(id: entry.id)
        } label: {
            Label(
                entry.starred ? "取消收藏" : "收藏",
                systemImage: entry.starred ? "star.slash" : "star"
            )
        }
        .tint(.orange)
    }

    private var deleteButton: some View {
        Button(role: .destructive) {
            store.remove(id: entry.id)
        } label: {
            Label("删除", systemImage: "trash")
        }
    }

    private var masteredButton: some View {
        Button {
            store.markReviewed(id: entry.id, mastered: !entry.mastered)
        } label: {
            Label(
                entry.mastered ? "标回未学" : "已掌握",
                systemImage: entry.mastered ? "arrow.uturn.backward" : "checkmark"
            )
        }
        .tint(.green)
    }

    private var displayOriginal: String {
        let text = entry.result.original.trimmingCharacters(in: .whitespacesAndNewlines)
        return text.isEmpty ? entry.term : text
    }
}

// MARK: - 辅助类型

private struct DayGroup: Identifiable {
    let id: Date
    let title: String
    let entries: [VocabularyEntry]
}

private struct ExportPayload: Identifiable {
    let id = UUID()
    let url: URL
}
