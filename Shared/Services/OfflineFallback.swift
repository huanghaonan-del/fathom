import SwiftUI

#if canImport(Translation)
import Translation

/// 离线兜底：调用苹果设备端 Translation 框架，只给译文，不联网。
/// 需要 iOS 18 或更高版本，且该语言对已下载（首次使用会请求下载，之后离线可用）。
struct OfflineTranslationSection: View {
    let text: String

    @State private var configuration: TranslationSession.Configuration?
    @State private var output: String = ""
    @State private var errorMessage: String?
    @State private var isWorking = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if output.isEmpty && errorMessage == nil {
                Button {
                    start()
                } label: {
                    Label(isWorking ? "正在离线翻译…" : "离线翻译（仅译文）", systemImage: "arrow.triangle.2.circlepath")
                        .font(.footnote.weight(.medium))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(isWorking)
            }

            if !output.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Label("离线翻译", systemImage: "wifi.slash")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(output)
                        .font(.callout)
                        .textSelection(.enabled)
                }
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .translationTask(configuration) { session in
            await run(session)
        }
    }

    private func start() {
        var config = TranslationSession.Configuration(
            source: Locale.Language(identifier: "en"),
            target: Locale.Language(identifier: "zh-Hans")
        )
        config.invalidate()
        configuration = config
        isWorking = true
    }

    private func run(_ session: TranslationSession) async {
        do {
            let response = try await session.translate(text)
            output = response.targetText
            errorMessage = nil
        } catch {
            errorMessage = "离线翻译不可用：\(error.localizedDescription)"
        }
        isWorking = false
        configuration = nil
    }
}

#else

/// 当前 Xcode 的 SDK 里没有 Translation 框架时，静默隐藏该功能。
struct OfflineTranslationSection: View {
    let text: String

    var body: some View {
        EmptyView()
    }
}

#endif
