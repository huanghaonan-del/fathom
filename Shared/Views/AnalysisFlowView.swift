import SwiftUI
import UIKit

/// 解析主界面。Action Extension 与主 App（历史记录详情、手动输入）共用这一份。
@MainActor
struct AnalysisFlowView: View {
    @State private var viewModel: AnalysisViewModel
    @State private var isEditing = false
    @State private var draftText = ""
    @State private var draftKind: AnalysisKind = .sentence
    @State private var didAutoStart = false
    @State private var toast: String?
    /// 走 URL 回传给主 App 保存时用，避免按钮重复点击。
    @State private var savedExternally = false

    private let autoStart: Bool
    private let showsCloseButton: Bool
    private let onClose: (() -> Void)?
    /// 扩展拿不到 App Group 时，不写自己的沙盒，而是把结果回传主 App 保存。
    private let onSaveResult: ((AnalysisResult) -> Void)?

    init(
        text: String,
        kind: AnalysisKind? = nil,
        vocabulary: VocabularyStore,
        autoStart: Bool = true,
        showsCloseButton: Bool = true,
        onClose: (() -> Void)? = nil,
        onSaveResult: ((AnalysisResult) -> Void)? = nil
    ) {
        _viewModel = State(initialValue: AnalysisViewModel(
            initialText: text,
            kind: kind,
            vocabulary: vocabulary,
            autoSave: onSaveResult == nil
        ))
        self.autoStart = autoStart
        self.showsCloseButton = showsCloseButton
        self.onClose = onClose
        self.onSaveResult = onSaveResult
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    selectionCard
                    kindPicker
                    phaseContent
                }
                .padding(16)
            }
            .scrollDismissesKeyboard(.interactively)
            .safeAreaInset(edge: .bottom) { bottomBar }
            .navigationTitle("Fathom")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if showsCloseButton {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            onClose?()
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title3)
                                .symbolRenderingMode(.hierarchical)
                                .foregroundStyle(.secondary)
                        }
                        .accessibilityLabel("关闭")
                    }
                }
            }
            .task {
                guard !didAutoStart else { return }
                didAutoStart = true
                if autoStart && !viewModel.input.isEmpty {
                    viewModel.start()
                }
            }
            .sheet(isPresented: $isEditing) { editorSheet }
            .overlay(alignment: .bottom) {
                if let toast {
                    Text(toast)
                        .font(.footnote.weight(.semibold))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(.ultraThinMaterial, in: Capsule())
                        .padding(.bottom, 70)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
            }
        }
    }

    // MARK: - 选中内容

    private var selectionCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("选中内容", systemImage: "text.cursor")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Button {
                    draftText = viewModel.input
                    draftKind = viewModel.kind
                    isEditing = true
                } label: {
                    Label("编辑", systemImage: "pencil")
                        .font(.caption.weight(.semibold))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.tint)
            }

            Text(viewModel.input.isEmpty ? "（没有收到文字）" : viewModel.input)
                .font(.callout)
                .lineLimit(viewModel.isLoading ? 2 : 4)
                .textSelection(.enabled)
                .foregroundStyle(viewModel.input.isEmpty ? .secondary : .primary)

            Text("\(viewModel.input.count) 字符")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(alignment: .leading) {
            RoundedRectangle(cornerRadius: 2)
                .fill(Color.accentColor.opacity(0.6))
                .frame(width: 3)
                .padding(.vertical, 12)
        }
    }

    private var kindPicker: some View {
        Picker("解析类型", selection: Binding(
            get: { viewModel.kind },
            set: { viewModel.setKind($0) }
        )) {
            ForEach(AnalysisKind.allCases, id: \.self) { kind in
                Text(kind.toggleTitle).tag(kind)
            }
        }
        .pickerStyle(.segmented)
        .disabled(viewModel.isLoading)
        .onChange(of: viewModel.kind) {
            if !viewModel.input.isEmpty {
                viewModel.start()
            }
        }
    }

    // MARK: - 各阶段

    @ViewBuilder
    private var phaseContent: some View {
        switch viewModel.phase {
        case .idle:
            VStack(alignment: .leading, spacing: 10) {
                Text("点下方按钮开始解析。正在联网调用你配置的服务。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

        case .loading:
            LoadingPlaceholder(label: viewModel.kind == .word ? "正在查这个词…" : "正在拆解这个句子…")

        case .success(let result):
            AnalysisResultView(result: result, showOfflineFallback: SettingsStore.load().offlineFallbackEnabled)

        case .failure(let message):
            ErrorCard(message: message, onRetry: { viewModel.retry() })
        }
    }

    // MARK: - 底部操作

    private var bottomBar: some View {
        HStack(spacing: 10) {
            switch viewModel.phase {
            case .loading:
                Button(role: .cancel) {
                    viewModel.cancel()
                } label: {
                    Text("取消").frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)

            case .success(let result):
                Button {
                    copy(result)
                } label: {
                    Label("复制结果", systemImage: "doc.on.doc")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)

                Button {
                    viewModel.start()
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.bordered)
                .accessibilityLabel("重新解析")

                let saved = viewModel.savedToVocabulary || savedExternally
                Button {
                    if let onSaveResult {
                        onSaveResult(result)
                        savedExternally = true
                        showToast("已发给 Fathom 保存")
                    } else {
                        viewModel.saveToVocabulary(result)
                    }
                } label: {
                    Label(saved ? "已加入" : "加入生词本",
                          systemImage: saved ? "bookmark.fill" : "bookmark")
                        .labelStyle(.titleAndIcon)
                        .font(.callout)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(saved)
                .accessibilityLabel("存入生词本")

            case .idle, .failure:
                Button {
                    viewModel.start()
                } label: {
                    Label("开始解析", systemImage: "sparkles")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.input.isEmpty)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.bar)
    }

    private func copy(_ result: AnalysisResult) {
        UIPasteboard.general.string = result.plainText
        showToast("已复制")
    }

    private func showToast(_ message: String) {
        withAnimation(.easeOut(duration: 0.2)) { toast = message }
        Task {
            try? await Task.sleep(for: .seconds(1.6))
            withAnimation(.easeIn(duration: 0.2)) {
                if toast == message { toast = nil }
            }
        }
    }

    // MARK: - 编辑选中文字

    private var editorSheet: some View {
        NavigationStack {
            Form {
                Section("要解析的文字") {
                    TextEditor(text: $draftText)
                        .frame(minHeight: 120)
                        .font(.body)
                }
                Section {
                    Picker("解析类型", selection: $draftKind) {
                        ForEach(AnalysisKind.allCases, id: \.self) { kind in
                            Text(kind.displayName).tag(kind)
                        }
                    }
                    .pickerStyle(.segmented)
                } footer: {
                    Text("单个词或很短的短语选「单词」，完整句子选「句子」。")
                }
            }
            .navigationTitle("修改选中内容")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { isEditing = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("解析") {
                        viewModel.setInput(draftText)
                        viewModel.setKind(draftKind)
                        isEditing = false
                        viewModel.start()
                    }
                    .disabled(draftText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
