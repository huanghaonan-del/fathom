import SwiftUI

/// Action Extension 的 SwiftUI 根视图。
@MainActor
struct ActionRootView: View {
    let text: String
    let store: VocabularyStore
    let onClose: () -> Void
    /// 由 ActionViewController 传入，用来打开 fathom:// 链接或浏览器。
    var openURL: ((URL) -> Void)? = nil

    /// 扩展读不到主 App 填的 Key 时（免费账号常见），先让用户补填一次。
    @State private var needsSetup = !SettingsStore.load().isConfigured

    var body: some View {
        Group {
            if needsSetup {
                ExtensionSetupView(openURL: openURL) {
                    needsSetup = false
                }
            } else if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                EmptySelectionView(onClose: onClose)
            } else if TextNormalizer.isBareLink(text) {
                LinkOnlyView(onClose: onClose)
            } else {
                AnalysisFlowView(
                    text: text,
                    kind: nil,
                    vocabulary: store,
                    autoStart: true,
                    showsCloseButton: true,
                    onClose: onClose,
                    onSaveResult: SharedStorage.isUsingAppGroup ? nil : handoff
                )
            }
        }
    }

    /// 没有 App Group 时，把结果通过 URL 送回主 App 保存进生词本。
    private func handoff(_ result: AnalysisResult) {
        guard let url = DeepLinkCodec.saveURL(for: result) else { return }
        openURL?(url)
    }
}

private struct EmptySelectionView: View {
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "text.cursor")
                .font(.system(size: 34))
                .foregroundStyle(.tertiary)
            Text("没有收到文字")
                .font(.headline)
            Text("先在 App 里长按选中一段英文，再点分享 → Fathom。\n部分 App（例如 Safari 阅读器模式）需要先选中文字才会出现本扩展。")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
            Button("关闭") {
                onClose()
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(24)
    }
}

/// 只拿到链接时（X、Instagram 等）显示的提示，比「解析一个网址」有用得多。
private struct LinkOnlyView: View {
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "link")
                .font(.system(size: 34))
                .foregroundStyle(.tertiary)
            Text("这个 App 只分享了链接")
                .font(.headline)
            Text("X、Instagram 这类 App 分享时通常只给帖子链接，不给选中的文字。\n\n两种办法：\n① 在页面里长按选中要读的句子 → 复制 → 打开 Fathom 的「解析」页粘贴；\n② 换成 Safari 打开该页面，选中文字后从分享面板调起 Fathom。")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.leading)
                .padding(.horizontal, 20)
            Button("关闭") {
                onClose()
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(24)
    }
}
