import SwiftUI
import UIKit

struct EntryDetailView: View {
    let entry: VocabularyEntry
    let store: VocabularyStore

    @Environment(\.dismiss) private var dismiss
    @State private var isReanalyzing = false
    @State private var copied = false
    @State private var showDeleteConfirm = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Label("原选中内容", systemImage: "text.cursor")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(entry.result.original)
                        .font(.callout)
                        .textSelection(.enabled)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

                AnalysisResultView(result: entry.result, showOfflineFallback: true)

                Text("收录于 \(entry.createdAt.formatted(date: .abbreviated, time: .shortened))")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .padding(16)
        }
        .navigationTitle(entry.term)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    UIPasteboard.general.string = entry.result.plainText
                    copied = true
                    Task {
                        try? await Task.sleep(for: .seconds(1.5))
                        copied = false
                    }
                } label: {
                    Image(systemName: copied ? "checkmark" : "doc.on.doc")
                }
                .accessibilityLabel("复制")
            }
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        isReanalyzing = true
                    } label: {
                        Label("重新解析", systemImage: "arrow.clockwise")
                    }
                    Button {
                        UIPasteboard.general.string = entry.term
                    } label: {
                        Label("复制单词", systemImage: "textformat.abc")
                    }
                    Divider()
                    Button(role: .destructive) {
                        showDeleteConfirm = true
                    } label: {
                        Label("从生词本删除", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $isReanalyzing) {
            AnalysisFlowView(
                text: entry.term,
                kind: entry.kind,
                vocabulary: store,
                autoStart: true,
                showsCloseButton: true,
                onClose: { isReanalyzing = false }
            )
        }
        .confirmationDialog("删除这条记录？", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("删除", role: .destructive) {
                store.remove(id: entry.id)
                dismiss()
            }
            Button("取消", role: .cancel) {}
        }
    }
}
