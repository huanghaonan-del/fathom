import Foundation
import Observation

/// 解析流程的编排层：选提示词 → 调服务 → 必要时修复 JSON → 返回结果。
struct AnalysisService {
    let settings: EngineSettings
    private let client: LLMClient

    init(settings: EngineSettings) {
        self.settings = settings
        self.client = LLMClient(settings: settings)
    }

    /// 校验与归一化，卡片解析和深度讲解共用。
    private func prepare(_ request: AnalysisRequest) throws -> AnalysisRequest {
        let text: String
        switch request.kind {
        case .word:
            text = TextNormalizer.stripWordPunctuation(request.text)
        case .sentence:
            text = request.text
        }

        let normalized = AnalysisRequest(text: text, kind: request.kind, sourceHint: request.sourceHint)
        guard !normalized.text.isEmpty else { throw AnalysisError.emptyInput }

        // 只拿到链接时不要浪费一次请求去「解析」一个网址。
        if TextNormalizer.isBareLink(normalized.text) {
            throw AnalysisError.invalidConfiguration(
                "收到的是一条链接，不是文字。\n请在页面里长按选中要读的句子再分享给 Fathom；或者先复制文字，用 App 里的「解析」页粘贴。"
            )
        }

        guard settings.isConfigured else {
            if settings.requiresAPIKey,
               settings.apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                throw AnalysisError.missingAPIKey
            }
            throw AnalysisError.invalidConfiguration("服务配置不完整，请到设置里检查 Base URL 与模型名。")
        }

        return normalized
    }

    func analyze(_ request: AnalysisRequest) async throws -> AnalysisResult {
        let normalized = try prepare(request)
        let prompt = PromptBuilder.make(for: normalized)
        do {
            return try await client.analyze(normalized, prompt: prompt)
        } catch let error as AnalysisError {
            guard case .malformedResponse(let rawOutput) = error else { throw error }
            // 只有「格式不对」才值得再花一次请求去修复。
            return try await client.repair(rawOutput, request: normalized)
        }
    }

    /// 「讲深一点」：另一次请求，返回一整节课。
    func makeLesson(_ request: AnalysisRequest) async throws -> Lesson {
        let normalized = try prepare(request)
        return try await client.lesson(for: normalized)
    }
}

/// Action Extension 与主 App 共用的解析视图状态机。
@MainActor
@Observable
final class AnalysisViewModel {
    enum Phase: Equatable {
        case idle
        case loading
        case success(AnalysisResult)
        case failure(String)
    }

    private(set) var phase: Phase = .idle
    private(set) var input: String = ""
    private(set) var kind: AnalysisKind = .sentence
    var savedToVocabulary: Bool = false

    private let vocabulary: VocabularyStore
    /// 扩展里没有共享容器时不能自存（存了主 App 也看不到），改走 URL 回传。
    private let autoSave: Bool
    private var task: Task<Void, Never>?

    init(initialText: String = "", kind: AnalysisKind? = nil, vocabulary: VocabularyStore, autoSave: Bool = true) {
        self.vocabulary = vocabulary
        self.autoSave = autoSave
        let normalized = TextNormalizer.normalize(initialText)
        self.input = normalized
        self.kind = kind ?? TextNormalizer.guessKind(normalized)
    }

    var isLoading: Bool {
        if case .loading = phase { return true }
        return false
    }

    var result: AnalysisResult? {
        if case .success(let result) = phase { return result }
        return nil
    }

    func setInput(_ text: String) {
        let normalized = TextNormalizer.normalize(text)
        input = normalized
        kind = TextNormalizer.guessKind(normalized)
    }

    func setKind(_ newKind: AnalysisKind) {
        kind = newKind
    }

    func start() {
        guard !input.isEmpty else {
            phase = .failure(AnalysisError.emptyInput.errorDescription ?? "没有内容")
            return
        }

        let settings = SettingsStore.load()
        let request = AnalysisRequest(text: input, kind: kind)
        let service = AnalysisService(settings: settings)

        phase = .loading
        task?.cancel()
        task = Task { [weak self] in
            do {
                let result = try await service.analyze(request)
                guard !Task.isCancelled, let self else { return }
                self.phase = .success(result)
                self.savedToVocabulary = autoSave ? (self.vocabulary.add(result) != nil) : false
            } catch {
                guard !Task.isCancelled, let self else { return }
                if error is CancellationError { return }
                let message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
                self.phase = .failure(message)
            }
        }
    }

    func retry() {
        start()
    }

    func cancel() {
        task?.cancel()
        task = nil
        if case .loading = phase { phase = .idle }
    }

    func saveToVocabulary(_ result: AnalysisResult) {
        savedToVocabulary = vocabulary.add(result) != nil
    }
}
