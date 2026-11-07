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
            guard let text = items.first(where: { $0.name == "text" })?.value else { return nil }
            let normalized = TextNormalizer.normalize(text)
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
        .fullScreenCover(item: $deepLink) { request in
            AnalysisFlowView(
                text: request.text,
                kind: request.kind,
                vocabulary: store,
                autoStart: true,
                showsCloseButton: true,
                onClose: { deepLink = nil }
            )
        }
        .onOpenURL { url in
            // 扩展回传的结果：直接存进生词本，不打断当前操作。
            if let result = DeepLinkCodec.result(from: url) {
                _ = store.add(result)
                selectedTab = 0
                return
            }
            if let request = DeepLinkRequest(url: url) {
                deepLink = request
            }
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
        deepLink = DeepLinkRequest(text: normalized, kind: TextNormalizer.guessKind(normalized))
    }
}
