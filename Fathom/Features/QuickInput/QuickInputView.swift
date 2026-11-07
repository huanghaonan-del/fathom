import SwiftUI

/// 「解析」标签页：手输 / 粘贴一段英文直接解析。
/// 给分享菜单拿不到文字的 App 兜底（例如 X 的长按菜单），也方便精读时整理长句。
struct QuickInputView: View {
    let store: VocabularyStore

    @State private var text = ""
    @State private var kind: AnalysisKind = .sentence
    @State private var presentFlow = false
    /// 粘贴进来的其实是「保存链接」时，给一句确认。
    @State private var savedNotice = false
    @FocusState private var focused: Bool

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    editor

                    Picker("解析类型", selection: $kind) {
                        ForEach(AnalysisKind.allCases, id: \.self) { item in
                            Text(item.toggleTitle).tag(item)
                        }
                    }
                    .pickerStyle(.segmented)

                    HStack(spacing: 10) {
                        PasteButton(payloadType: String.self) { strings in
                            guard let first = strings.first else { return }
                            if let result = DeepLinkCodec.result(fromPastedText: first) {
                                _ = store.add(result)
                                savedNotice = true
                                return
                            }
                            text = first
                            kind = TextNormalizer.guessKind(first)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.large)

                        Spacer(minLength: 0)

                        Button {
                            if let result = DeepLinkCodec.result(fromPastedText: text) {
                                _ = store.add(result)
                                text = ""
                                savedNotice = true
                                return
                            }
                            presentFlow = true
                        } label: {
                            Label("开始解析", systemImage: "sparkles")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .disabled(trimmedText.isEmpty)
                    }

                    tips
                }
                .padding(16)
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("解析")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("清空") {
                        text = ""
                    }
                    .disabled(text.isEmpty)
                }
                ToolbarItem(placement: .keyboard) {
                    HStack {
                        Spacer()
                        Button("收起键盘") { focused = false }
                    }
                }
            }
            .sheet(isPresented: $presentFlow) {
                AnalysisFlowView(
                    text: text,
                    kind: kind,
                    vocabulary: store,
                    autoStart: true,
                    showsCloseButton: true,
                    onClose: { presentFlow = false }
                )
            }
            .alert("已存入生词本", isPresented: $savedNotice) {
                Button("好", role: .cancel) {}
            } message: {
                Text("这条结果是从分享扩展传来的，已经保存。可以到「生词本」查看。")
            }
        }
    }

    private var trimmedText: String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var editor: some View {
        ZStack(alignment: .topLeading) {
            TextEditor(text: $text)
                .focused($focused)
                .scrollContentBackground(.hidden)
                .frame(minHeight: 180)
                .padding(8)

            if text.isEmpty {
                Text("粘贴或输入英文单词 / 句子…")
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, 13)
                    .padding(.vertical, 16)
                    .allowsHitTesting(false)
            }
        }
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var tips: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("单词：音标、词性、释义、搭配、例句", systemImage: "character.book.closed")
            Label("句子：整句翻译、主谓宾、从句、难点词", systemImage: "text.alignleft")
            Label("在别的 App 里选中文字直接分享给 Fathom 也可以", systemImage: "square.and.arrow.up")
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color(.secondarySystemBackground).opacity(0.6), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}
