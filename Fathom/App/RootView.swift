import SwiftUI
import UIKit

/// 从 URL Scheme 带进来的解析请求。
struct DeepLinkRequest: Identifiable, Equatable {
    let id = UUID()
    let text: String
    let kind: AnalysisKind

    init(text: String, kind: AnalysisKind) {
        self.text = text
        self.kind = kind
    }

    init?(url: URL) {
        guard url.scheme?.lowercased() == "fathom" else { return nil }
        let host = url.host?.lowercased() ?? ""

        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return nil }
        let items = components.queryItems ?? []

        switch host {
        case "analyze", "add":
            let raw = items.first(where: { $0.name == "text" })?.value ?? ""
            // 不带 text 时读剪贴板：这样快捷指令里只需要「打开 URL」一步。
            let source = raw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? (UIPasteboard.general.string ?? "")
                : raw
            let normalized = TextNormalizer.normalize(source)
            guard !normalized.isEmpty else { return nil }
            self.text = normalized
            if let mode = items.first(where: { $0.name == "mode" })?.value,
               let kind = AnalysisKind(rawValue: mode) {
                self.kind = kind
            } else {
                self.kind = TextNormalizer.guessKind(normalized)
            }

        default:
            return nil
        }
    }
}

struct RootView: View {
    let store: VocabularyStore

    @State private var deepLink: DeepLinkRequest?
    @State private var selectedTab: Int = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            LibraryView(
                store: store,
                onAnalyzeText: analyzeClipboard,
                onOpenSettings: { selectedTab = 2 }
            )
                .tabItem { Label("生词本", systemImage: "book.closed") }
                .tag(0)

            QuickInputView(store: store)
                .tabItem { Label("解析", systemImage: "text.magnifyingglass") }
                .tag(1)

            SettingsView(store: store)
                .tabItem { Label("设置", systemImage: "gearshape") }
                .tag(2)
        }
        .sheet(item: $deepLink) { request in
            AnalysisFlowView(
                text: request.text,
                kind: request.kind,
                vocabulary: store,
                autoStart: true,
                showsCloseButton: true,
                onClose: { deepLink = nil }
            )
            .presentationDetents([.fraction(0.62), .large])
            .presentationDragIndicator(.visible)
        }
        .onOpenURL { url in
            // 扩展回传的结果：直接存进生词本，不打断当前操作。
            if let result = DeepLinkCodec.result(from: url) {
                _ = store.add(result)
                selectedTab = 0
                return
            }
            if let request = DeepLinkRequest(url: url) {
                present(request)
            }
        }
    }

    /// 半屏已经开着时又来一次请求：先收起旧的，等收起动画结束再弹新的，
    /// 否则 SwiftUI 会忽略这次赋值，看起来像「点了没反应」。
    private func present(_ request: DeepLinkRequest) {
        guard deepLink != nil else {
            deepLink = request
            return
        }
        deepLink = nil
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            deepLink = request
        }
    }

    private func analyzeClipboard() {
        guard let text = UIPasteboard.general.string,
              !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else { return }

        // 扩展唤起主 App 失败时，剪贴板里是一条「保存链接」，这里直接落库。
        if let result = DeepLinkCodec.result(fromPastedText: text) {
            _ = store.add(result)
            selectedTab = 0
            return
        }

        let normalized = TextNormalizer.normalize(text)
        guard !normalized.isEmpty else { return }
        present(DeepLinkRequest(text: normalized, kind: TextNormalizer.guessKind(normalized)))
    }
}
