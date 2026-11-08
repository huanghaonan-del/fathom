import AppIntents
import Foundation

/// 让「快捷指令」也能调用 Fathom 的解析能力。
///
/// 用途：用免费 Apple ID 侧载时，分享扩展偶尔无法被系统注册（分享面板里始终
/// 看不到 Fathom）。这时可以建一个快捷指令：
///   获取快捷指令输入 → 用 Fathom 解析 → 显示结果
/// 并在快捷指令的「详细信息」里打开 **在共享表单中显示**。它就会作为图标出现在
/// 分享面板第一行，点一下即可在后台解析，结果以弹层显示，不需要离开当前 App。
struct AnalyzeWithFathomIntent: AppIntent {
    static let title: LocalizedStringResource = "用 Fathom 解析"

    @Parameter(title: "文字")
    var text: String

    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        let normalized = TextNormalizer.normalize(text)
        let request = AnalysisRequest(
            text: normalized,
            kind: TextNormalizer.guessKind(normalized)
        )
        let result = try await AnalysisService(settings: SettingsStore.load()).analyze(request)
        return .result(value: result.plainText)
    }
}
