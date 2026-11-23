import SwiftUI
import UIKit

/// 「讲深一点」：把一句话讲成一节小课。
///
/// 和卡片解析分开，是因为它要慢一些、贵一些，但能讲透——
/// 拆句、比词、讲结构、讲母语者怎么想、给可套用的句子。
///
/// 三个体验点：
/// 1. 流式：一边生成一边把能读的部分显示出来，不用干等；
/// 2. 上下文：单句容易误判指代和语气，这里可以补一句前后文再重讲；
/// 3. 追问：讲完还能就着这节课继续问，答案接在下面。
@MainActor
struct LessonSheetView: View {
    let text: String
    let kind: AnalysisKind
    /// 传进来就会把讲解存到对应的词库记录里；扩展里一般传 nil。
    var store: VocabularyStore? = nil
    var result: AnalysisResult? = nil
    var onClose: () -> Void = {}

    @State private var phase: Phase = .loading
    @State private var copied = false
    @State private var savedToLibrary = false

    @State private var streamed = ""
    @State private var showContextField = false
    @State private var contextText = ""

    @State private var followUpText = ""
    @State private var exchanges: [Exchange] = []
    @State private var isAsking = false
    @State private var askError: String?

    struct Exchange: Identifiable, Equatable {
        let id = UUID()
        let question: String
        var answer: String
        var failed: Bool = false
    }

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
                    contextBar

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
            .scrollDismissesKeyboard(.interactively)
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
                            UIPasteboard.general.string = lesson.plainText + answersText
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

    // MARK: - 顶部

    private var quotedText: some View {
        HStack(alignment: .top, spacing: 10) {
            Rectangle()
                .fill(Color.accentColor.opacity(0.5))
                .frame(width: 3)
            Text(text)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            SpeakerButton(text: text, compact: true)
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private var contextBar: some View {
        VStack(alignment: .leading, spacing: 8) {
            if showContextField {
                TextField("前一句或后一句，只要一句就够", text: $contextText, axis: .vertical)
                    .lineLimit(1...3)
                    .font(.footnote)
                    .padding(10)
                    .background(Color(uiColor: .secondarySystemGroupedBackground),
                                in: RoundedRectangle(cornerRadius: 10, style: .continuous))

                HStack(spacing: 10) {
                    Button {
                        Task { await load() }
                    } label: {
                        Label("带上这段重讲", systemImage: "arrow.clockwise")
                            .font(.caption.weight(.medium))
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .disabled(phase == .loading)

                    Button("收起") {
                        withAnimation(.easeInOut(duration: 0.15)) { showContextField = false }
                    }
                    .font(.caption)
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                }
            } else {
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) { showContextField = true }
                } label: {
                    Label("补一句上下文", systemImage: "text.append")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - 状态

    private var loadingView: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                ProgressView()
                Text(streamed.isEmpty ? "正在整理这节课…" : "正在写第 \(streamed.count) 个字…")
                    .font(.subheadline.weight(.medium))
            }
            if streamed.isEmpty {
                Text("会先拆句子，再挑出换不掉的那个词，讲结构和母语者的想法。通常 10–25 秒。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                Text(peek(streamed))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .lineLimit(8)
            }
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

    // MARK: - 讲解

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
            if savedToLibrary {
                Label("已存进词库，下次在卡片里直接看", systemImage: "checkmark.circle")
                    .font(.caption2)
                    .foregroundStyle(.green)
                    .padding(.top, 6)
            }

            followUpSection
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
            HStack(alignment: .top, spacing: 8) {
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
                Spacer(minLength: 0)
                SpeakerButton(text: block.text, compact: true)
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

    // MARK: - 追问

    private var followUpSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Divider().padding(.top, 10)

            if !exchanges.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach($exchanges) { $exchange in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(exchange.question)
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(.secondary)
                            Text(exchange.answer)
                                .font(.footnote)
                                .foregroundStyle(exchange.failed ? .orange : .primary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(uiColor: .secondarySystemGroupedBackground),
                                    in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                }
            }

            HStack(spacing: 8) {
                TextField("还想问什么？", text: $followUpText, axis: .vertical)
                    .lineLimit(1...3)
                    .font(.footnote)
                    .padding(10)
                    .background(Color(uiColor: .secondarySystemGroupedBackground),
                                in: RoundedRectangle(cornerRadius: 10, style: .continuous))

                Button {
                    Task { await ask() }
                } label: {
                    if isAsking {
                        ProgressView()
                            .frame(width: 28, height: 28)
                    } else {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.title2)
                            .foregroundStyle(canAsk ? Color.accentColor : Color.secondary.opacity(0.4))
                    }
                }
                .buttonStyle(.plain)
                .disabled(!canAsk)
            }
        }
        .padding(.top, 4)
    }

    private var canAsk: Bool {
        !isAsking && !followUpText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func ask() async {
        let question = followUpText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !question.isEmpty, case .success(let lesson) = phase else { return }

        followUpText = ""
        isAsking = true
        askError = nil
        var exchange = Exchange(question: question, answer: "")
        exchanges.append(exchange)
        let index = exchanges.count - 1

        do {
            let answer = try await AnalysisService(settings: SettingsStore.load())
                .followUp(question: question, lessonText: lesson.plainText, sourceText: text)
            exchange.answer = answer
            exchanges[index] = exchange
        } catch {
            exchange.answer = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            exchange.failed = true
            exchanges[index] = exchange
        }
        isAsking = false
    }

    private var answersText: String {
        guard !exchanges.isEmpty else { return "" }
        let body = exchanges.map { "问：\($0.question)\n答：\($0.answer)" }.joined(separator: "\n\n")
        return "\n\n" + body
    }

    // MARK: - 数据

    private func load() async {
        phase = .loading
        streamed = ""
        savedToLibrary = false

        let context = contextText.trimmingCharacters(in: .whitespacesAndNewlines)
        let request = AnalysisRequest(text: text, kind: kind,
                                      context: context.isEmpty ? nil : context)
        let service = AnalysisService(settings: SettingsStore.load())

        do {
            let lesson = try await service.streamLesson(request) { piece in
                Task { @MainActor in
                    streamed += piece
                }
            }
            phase = .success(lesson)
            if let store, let result {
                store.saveLesson(lesson.plainText, for: result)
                savedToLibrary = true
            }
        } catch {
            if error is CancellationError { return }
            let message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            phase = .failure(message)
        }
    }

    /// 从流式收到的半截 JSON 里抠出已经写好的句子，让等待不那么空。
    private func peek(_ raw: String) -> String {
        guard raw.count > 30 else { return "" }
        guard let regex = try? NSRegularExpression(
            pattern: "\"(text|zh)\"\\s*:\\s*\"((?:[^\"\\\\]|\\\\.)*)\""
        ) else { return "" }

        let ns = raw as NSString
        let matches = regex.matches(in: raw, range: NSRange(location: 0, length: ns.length))
        var lines: [String] = []
        for match in matches {
            guard match.numberOfRanges >= 3 else { continue }
            let key = ns.substring(with: match.range(at: 1))
            let escaped = ns.substring(with: match.range(at: 2))
            if key == "zh" && escaped.isEmpty { continue }
            if let data = ("\"" + escaped + "\"").data(using: .utf8),
               let value = try? JSONDecoder().decode(String.self, from: data),
               !value.isEmpty {
                lines.append(value)
            }
        }
        return lines.suffix(8).joined(separator: "\n")
    }
}
