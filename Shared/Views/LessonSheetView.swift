import SwiftUI
import UIKit

/// 「讲深一点」：把一句话讲成一节小课。
///
/// 和卡片解析分开，是因为它要慢一些、贵一些，但能讲透——
/// 拆句、比词、讲结构、讲母语者怎么想、给可套用的句子。
@MainActor
struct LessonSheetView: View {
    let text: String
    let kind: AnalysisKind
    var onClose: () -> Void = {}

    @State private var phase: Phase = .loading
    @State private var copied = false

    enum Phase: Equatable {
        case loading
        case success(Lesson)
        case failure(String)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    quotedText

                    switch phase {
                    case .loading:
                        loadingView
                    case .failure(let message):
                        errorView(message)
                    case .success(let lesson):
                        lessonView(lesson)
                    }
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("讲深一点")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("关闭") { onClose() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    if case .success(let lesson) = phase {
                        Button {
                            UIPasteboard.general.string = lesson.plainText
                            copied = true
                            Task {
                                try? await Task.sleep(nanoseconds: 1_600_000_000)
                                copied = false
                            }
                        } label: {
                            Image(systemName: copied ? "checkmark" : "doc.on.doc")
                        }
                        .accessibilityLabel(copied ? "已复制" : "复制讲解")
                    }
                }
            }
            .task { await load() }
        }
    }

    // MARK: - 片段

    private var quotedText: some View {
        Text(text)
            .font(.footnote)
            .foregroundStyle(.secondary)
            .padding(.leading, 10)
            .overlay(alignment: .leading) {
                Rectangle()
                    .fill(Color.accentColor.opacity(0.5))
                    .frame(width: 3)
            }
    }

    private var loadingView: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                ProgressView()
                Text("正在整理这节课…")
                    .font(.subheadline.weight(.medium))
            }
            Text("会先拆句子，再挑出换不掉的那个词，讲结构和母语者的想法。通常 10–25 秒。")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(.top, 8)
    }

    private func errorView(_ message: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("没讲成", systemImage: "exclamationmark.triangle")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.orange)
            Text(message)
                .font(.footnote)
                .textSelection(.enabled)
            Button {
                Task { await load() }
            } label: {
                Label("再试一次", systemImage: "arrow.clockwise")
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
        .padding(.top, 4)
    }

    private func lessonView(_ lesson: Lesson) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            if !lesson.title.isEmpty {
                Text(lesson.title)
                    .font(.title3.weight(.semibold))
                    .fixedSize(horizontal: false, vertical: true)
            }
            ForEach(Array(lesson.blocks.enumerated()), id: \.offset) { item in
                blockView(item.element)
            }
            Text("讲解由 AI 生成，可能会有一两处不准，重点看它给的例句。")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .padding(.top, 8)
        }
        .padding(.top, 4)
    }

    @ViewBuilder
    private func blockView(_ block: LessonBlock) -> some View {
        switch block.kind {
        case "h2":
            Text(block.text)
                .font(.headline)
                .padding(.top, 10)
        case "step":
            VStack(alignment: .leading, spacing: 2) {
                Text(block.text)
                    .font(.subheadline.weight(.semibold))
                    .textSelection(.enabled)
                if !block.zh.isEmpty {
                    Text(block.zh)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.top, 6)
        case "bullet":
            HStack(alignment: .top, spacing: 8) {
                Text("·")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                VStack(alignment: .leading, spacing: 3) {
                    Text(block.text)
                        .font(.subheadline.weight(.medium))
                        .textSelection(.enabled)
                    if !block.zh.isEmpty {
                        Text(block.zh)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        case "example":
            VStack(alignment: .leading, spacing: 4) {
                Text(block.text)
                    .font(.subheadline)
                    .italic()
                    .textSelection(.enabled)
                if !block.zh.isEmpty {
                    Text(block.zh)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.accentColor.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
        case "rowhead":
            HStack(alignment: .top, spacing: 8) {
                Text(block.text).frame(maxWidth: .infinity, alignment: .leading)
                Text(block.zh).frame(width: 56, alignment: .leading)
                Text(block.note).frame(maxWidth: .infinity, alignment: .leading)
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .padding(.top, 4)
        case "row":
            HStack(alignment: .top, spacing: 8) {
                Text(block.text).frame(maxWidth: .infinity, alignment: .leading)
                Text(block.zh)
                    .foregroundStyle(.secondary)
                    .frame(width: 56, alignment: .leading)
                Text(block.note).frame(maxWidth: .infinity, alignment: .leading)
            }
            .font(.caption)
            .padding(.vertical, 5)
            .overlay(alignment: .bottom) {
                Divider().opacity(0.5)
            }
        default:
            Text(block.text)
                .font(.body)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - 数据

    private func load() async {
        phase = .loading
        let settings = SettingsStore.load()
        let service = AnalysisService(settings: settings)
        let request = AnalysisRequest(text: text, kind: kind)
        do {
            let lesson = try await service.makeLesson(request)
            phase = .success(lesson)
        } catch {
            if error is CancellationError { return }
            let message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            phase = .failure(message)
        }
    }
}
