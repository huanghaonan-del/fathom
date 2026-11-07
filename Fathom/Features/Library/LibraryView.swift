import SwiftUI

private struct ExportItem: Identifiable {
    let id = UUID()
    let url: URL
    let format: ExportFormat
}

struct LibraryView: View {
    let store: VocabularyStore
    /// 把剪贴板里的内容送去解析（交给 RootView 处理）。
    var onAnalyzeText: () -> Void = {}
    /// 跳到「设置」标签页。
    var onOpenSettings: () -> Void = {}

    @State private var query: String = ""
    @State private var exportItem: ExportItem?
    @State private var exportError: String?
    @State private var showClearConfirm = false

    var body: some View {
        NavigationStack {
            List {
                ForEach(filteredEntries) { entry in
                    NavigationLink(value: entry) {
                        row(for: entry)
                    }
                }
                .onDelete(perform: delete)
            }
            .listStyle(.plain)
            .navigationTitle("生词本")
            .navigationDestination(for: VocabularyEntry.self) { entry in
                EntryDetailView(entry: entry, store: store)
            }
            .searchable(text: $query, prompt: "搜索单词、释义或译文")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        onAnalyzeText()
                    } label: {
                        Image(systemName: "doc.on.clipboard")
                    }
                    .accessibilityLabel("解析剪贴板")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            export(.csv)
                        } label: {
                            Label("导出 CSV 表格", systemImage: "tablecells")
                        }
                        Button {
                            export(.anki)
                        } label: {
                            Label("导出 Anki 卡片", systemImage: "rectangle.stack")
                        }
                        Divider()
                        Button(role: .destructive) {
                            showClearConfirm = true
                        } label: {
                            Label("清空生词本", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                    .disabled(store.entries.isEmpty)
                }
            }
            .overlay {
                if filteredEntries.isEmpty {
                    emptyState
                }
            }
            .sheet(item: $exportItem) { item in
                ShareFileSheet(url: item.url)
                    .presentationDetents([.medium, .large])
            }
            .alert("导出失败", isPresented: Binding(
                get: { exportError != nil },
                set: { if !$0 { exportError = nil } }
            )) {
                Button("好", role: .cancel) { exportError = nil }
            } message: {
                Text(exportError ?? "")
            }
            .confirmationDialog("确定清空生词本？", isPresented: $showClearConfirm, titleVisibility: .visible) {
                Button("清空 \(store.entries.count) 条记录", role: .destructive) {
                    store.removeAll()
                }
                Button("取消", role: .cancel) {}
            } message: {
                Text("清空后无法恢复。建议先导出备份。")
            }
        }
    }

    private var filteredEntries: [VocabularyEntry] {
        let keyword = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !keyword.isEmpty else { return store.entries }
        return store.entries.filter { entry in
            entry.term.lowercased().contains(keyword)
                || entry.summary.lowercased().contains(keyword)
                || entry.result.searchableText.lowercased().contains(keyword)
        }
    }

    private func row(for entry: VocabularyEntry) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(entry.term)
                    .font(.headline)
                    .lineLimit(1)
                if !entry.phonetic.isEmpty {
                    Text(entry.phonetic)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                Text(entry.kind.displayName)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            if !entry.summary.isEmpty {
                Text(entry.summary)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            Text(entry.createdAt.formatted(date: .abbreviated, time: .shortened))
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            if query.isEmpty {
                Image(systemName: "book.closed")
                    .font(.system(size: 38))
                    .foregroundStyle(.tertiary)
                Text("生词本还是空的")
                    .font(.headline)
                Text("在任意 App 里选中英文 → 分享 → 用 Fathom 解析，结果会自动收进来。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 36)
                Button {
                    onOpenSettings()
                } label: {
                    Label("先去填 API Key", systemImage: "key")
                }
                .buttonStyle(.bordered)
                .padding(.top, 4)
            } else {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 32))
                    .foregroundStyle(.tertiary)
                Text("没有匹配的记录")
                    .font(.headline)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }

    private func delete(at offsets: IndexSet) {
        let ids = offsets.map { filteredEntries[$0].id }
        store.remove(ids: Set(ids))
    }

    private func export(_ format: ExportFormat) {
        do {
            let url = try ExportService.makeFile(entries: store.entries, format: format)
            exportItem = ExportItem(url: url, format: format)
        } catch {
            exportError = error.localizedDescription
        }
    }
}
