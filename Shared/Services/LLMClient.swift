import Foundation

/// 与大模型 / 翻译服务通信的客户端。只依赖 URLSession，任何 SwiftUI 界面都能用。
struct LLMClient {
    let settings: EngineSettings
    var session: URLSession = .shared

    func analyze(_ request: AnalysisRequest, prompt: AnalysisPrompt) async throws -> AnalysisResult {
        guard !request.text.isEmpty else { throw AnalysisError.emptyInput }

        switch settings.provider {
        case .deepL:
            return try await analyzeWithDeepL(request)
        case .anthropic:
            return try await analyzeWithAnthropic(request, prompt: prompt)
        case .openAI, .deepSeek, .compatible:
            return try await analyzeWithChatCompletions(request, prompt: prompt)
        }
    }

    /// JSON 修复请求：把模型啰嗦的原始输出压回结构化 JSON。
    func repair(_ rawOutput: String, request: AnalysisRequest) async throws -> AnalysisResult {
        let prompt = PromptBuilder.repair(rawOutput: rawOutput, request: request)

        switch settings.provider {
        case .deepL:
            throw AnalysisError.invalidConfiguration("当前使用的服务不支持结构化解析。")
        case .anthropic:
            return try await analyzeWithAnthropic(request, prompt: prompt)
        case .openAI, .deepSeek, .compatible:
            return try await analyzeWithChatCompletions(request, prompt: prompt)
        }
    }

    /// 「讲深一点」：返回一整节课。卡片解析和讲解用的是同一套鉴权与容错。
    func lesson(for request: AnalysisRequest) async throws -> Lesson {
        switch settings.provider {
        case .deepL:
            throw AnalysisError.invalidConfiguration("DeepL 只能翻译，给不了讲解。请在设置里换成 DeepSeek 或 OpenAI。")
        case .anthropic:
            throw AnalysisError.invalidConfiguration("深度讲解目前只支持 OpenAI / DeepSeek / 兼容接口，Claude 请先用「快速解析」。")
        case .openAI, .deepSeek, .compatible:
            let prompt = PromptBuilder.makeLesson(for: request)
            let content = try await chatContent(prompt: prompt, maxTokens: 3000, timeout: 120)
            guard let lesson = ModelOutputParser.parseLesson(content), !lesson.blocks.isEmpty else {
                throw AnalysisError.malformedResponse(String(content.prefix(200)))
            }
            return lesson
        }
    }

    /// 流式版讲解：每收到一小段就回调一次，界面可以边到边显示。
    ///
    /// 注意这里不在请求里加 `response_format`：模型流式输出时如果被强制 JSON，
    /// 中途几乎没有可读的字符，用户看到的仍是转圈。让它正常写，最后再解析。
    func streamLesson(for request: AnalysisRequest,
                      onDelta: @escaping @Sendable (String) -> Void) async throws -> Lesson {
        switch settings.provider {
        case .deepL, .anthropic:
            return try await lesson(for: request)
        case .openAI, .deepSeek, .compatible:
            let prompt = PromptBuilder.makeLesson(for: request)
            let raw = try await streamContent(prompt: prompt, maxTokens: 3000, timeout: 150, onDelta: onDelta)
            guard let lesson = ModelOutputParser.parseLesson(raw), !lesson.blocks.isEmpty else {
                throw AnalysisError.malformedResponse(String(raw.prefix(200)))
            }
            return lesson
        }
    }

    /// 追问：纯文本回答，不走 JSON。
    func followUp(question: String, lessonText: String, sourceText: String) async throws -> String {
        switch settings.provider {
        case .deepL:
            throw AnalysisError.invalidConfiguration("DeepL 只能翻译，没法回答追问。")
        case .anthropic, .openAI, .deepSeek, .compatible:
            let prompt = PromptBuilder.followUp(question: question, lessonText: lessonText, sourceText: sourceText)
            let content = try await chatContent(prompt: prompt, maxTokens: 900, timeout: 90, jsonMode: false)
            let cleaned = content.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !cleaned.isEmpty else { throw AnalysisError.emptyResponse }
            return cleaned
        }
    }

    // MARK: - OpenAI 兼容接口（OpenAI / DeepSeek / 自建 / Ollama）
    private func analyzeWithChatCompletions(_ request: AnalysisRequest, prompt: AnalysisPrompt) async throws -> AnalysisResult {
        let content = try await chatContent(prompt: prompt, maxTokens: 2600)
        return try decodeResult(from: content, request: request, engineName: settings.provider.shortName)
    }

    /// 只负责「发一次对话、拿回文本」，卡片解析和深度讲解共用。
    private func chatContent(prompt: AnalysisPrompt, maxTokens: Int,
                             timeout: TimeInterval = 45, jsonMode: Bool = true) async throws -> String {
        let url = try chatEndpoint()
        var body = chatBody(prompt: prompt, maxTokens: maxTokens, stream: false)
        if jsonMode, settings.provider.supportsJSONMode {
            body["response_format"] = ["type": "json_object"]
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.timeoutInterval = timeout
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if settings.requiresAPIKey {
            urlRequest.setValue("Bearer \(settings.apiKey.trimmingCharacters(in: .whitespacesAndNewlines))",
                                forHTTPHeaderField: "Authorization")
        }
        urlRequest.httpBody = try JSONSerialization.data(withJSONObject: body)

        return try await extractChatContentWithRetry(urlRequest)
    }

    /// 流式：按 SSE 逐行读，把每个 delta 交回去。
    private func streamContent(prompt: AnalysisPrompt, maxTokens: Int, timeout: TimeInterval,
                               onDelta: @escaping @Sendable (String) -> Void) async throws -> String {
        let url = try chatEndpoint()
        let body = chatBody(prompt: prompt, maxTokens: maxTokens, stream: true)

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.timeoutInterval = timeout
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if settings.requiresAPIKey {
            urlRequest.setValue("Bearer \(settings.apiKey.trimmingCharacters(in: .whitespacesAndNewlines))",
                                forHTTPHeaderField: "Authorization")
        }
        urlRequest.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (bytes, response) = try await session.bytes(for: urlRequest)
        guard let http = response as? HTTPURLResponse else {
            throw AnalysisError.network("没有收到有效响应。")
        }
        guard (200..<300).contains(http.statusCode) else {
            var collected = Data()
            for try await line in bytes.lines {
                collected.append(contentsOf: Array(line.utf8))
                if collected.count > 400 { break }
            }
            let message = String(data: collected, encoding: .utf8) ?? ""
            throw AnalysisError.server(status: http.statusCode, message: message)
        }

        var full = ""
        for try await line in bytes.lines {
            guard line.hasPrefix("data:") else { continue }
            let payload = line.dropFirst(5).trimmingCharacters(in: .whitespaces)
            if payload == "[DONE]" { break }
            guard let data = payload.data(using: .utf8),
                  let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let choices = root["choices"] as? [[String: Any]],
                  let delta = choices.first?["delta"] as? [String: Any],
                  let piece = delta["content"] as? String,
                  !piece.isEmpty
            else { continue }
            full += piece
            onDelta(piece)
        }

        guard !full.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw AnalysisError.emptyResponse
        }
        return full
    }

    private func chatEndpoint() throws -> URL {
        guard let baseURL = settings.resolvedBaseURL else {
            throw AnalysisError.invalidConfiguration("Base URL 不正确，请在设置里填写以 http(s):// 开头的地址。")
        }
        if settings.requiresAPIKey,
           settings.apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw AnalysisError.missingAPIKey
        }
        if baseURL.path.hasSuffix("/chat/completions") { return baseURL }
        return baseURL.appendingPathComponent("chat/completions")
    }

    private func chatBody(prompt: AnalysisPrompt, maxTokens: Int, stream: Bool) -> [String: Any] {
        var body: [String: Any] = [
            "model": settings.resolvedModel,
            "temperature": 0.2,
            "stream": stream,
            "max_tokens": maxTokens,
            "messages": [
                ["role": "system", "content": prompt.system],
                ["role": "user", "content": prompt.user]
            ]
        ]
        // DeepSeek 默认开启思考模式，会显著拖慢返回速度。
        // 划词场景要的是秒回，所以明确关掉思考（关掉后 temperature 才生效）。
        if settings.provider == .deepSeek {
            body["thinking"] = ["type": "disabled"]
        }
        return body
    }

    /// JSON 模式下，模型偶尔会返回纯空白内容（官方文档明确提到这一点）。
    /// 这种情况重发一次通常就正常了，比直接把错误抛给用户友好得多。
    private func extractChatContentWithRetry(_ urlRequest: URLRequest) async throws -> String {
        let first = try await perform(urlRequest)
        let content = try extractChatContent(from: first)
        if !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return content
        }
        let second = try await perform(urlRequest)
        let retried = try extractChatContent(from: second)
        guard !retried.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw AnalysisError.emptyResponse
        }
        return retried
    }

    private func extractChatContent(from data: Data) throws -> String {
        guard
            let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let choices = root["choices"] as? [[String: Any]],
            let first = choices.first,
            let message = first["message"] as? [String: Any]
        else {
            let snippet = String(data: data.prefix(300), encoding: .utf8) ?? ""
            throw AnalysisError.malformedResponse("响应里没有 choices 字段：\(snippet)")
        }

        if let content = message["content"] as? String {
            return content
        }
        // 部分模型把内容拆成数组返回。
        if let parts = message["content"] as? [[String: Any]] {
            let joined = parts.compactMap { $0["text"] as? String }.joined()
            if !joined.isEmpty { return joined }
        }
        if let reasoning = message["reasoning_content"] as? String, !reasoning.isEmpty {
            return reasoning
        }
        throw AnalysisError.emptyResponse
    }

    // MARK: - Anthropic Messages API

    private func analyzeWithAnthropic(_ request: AnalysisRequest, prompt: AnalysisPrompt) async throws -> AnalysisResult {
        guard let baseURL = settings.resolvedBaseURL else {
            throw AnalysisError.invalidConfiguration("Base URL 不正确，请在设置里填写以 http(s):// 开头的地址。")
        }
        guard !settings.apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw AnalysisError.missingAPIKey
        }

        var url = baseURL
        if !url.path.hasSuffix("/messages") {
            url = url.appendingPathComponent("messages")
        }

        let body: [String: Any] = [
            "model": settings.resolvedModel,
            "max_tokens": 2600,
            "temperature": 0.2,
            "system": prompt.system,
            "messages": [
                ["role": "user", "content": prompt.user]
            ]
        ]

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.timeoutInterval = 45
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue(settings.apiKey.trimmingCharacters(in: .whitespacesAndNewlines),
                            forHTTPHeaderField: "x-api-key")
        urlRequest.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        urlRequest.httpBody = try JSONSerialization.data(withJSONObject: body)

        let data = try await perform(urlRequest)

        guard
            let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let blocks = root["content"] as? [[String: Any]]
        else {
            let snippet = String(data: data.prefix(300), encoding: .utf8) ?? ""
            throw AnalysisError.malformedResponse("响应里没有 content 字段：\(snippet)")
        }

        let text = blocks.compactMap { $0["text"] as? String }.joined()
        guard !text.isEmpty else { throw AnalysisError.emptyResponse }
        return try decodeResult(from: text, request: request, engineName: "Claude")
    }

    // MARK: - DeepL（只翻译）

    private func analyzeWithDeepL(_ request: AnalysisRequest) async throws -> AnalysisResult {
        guard let baseURL = settings.resolvedBaseURL else {
            throw AnalysisError.invalidConfiguration("Base URL 不正确。")
        }
        let key = settings.apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else { throw AnalysisError.missingAPIKey }

        let url = baseURL.appendingPathComponent("v2/translate")
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.timeoutInterval = 30
        urlRequest.setValue("application/x-www-form-urlencoded; charset=utf-8",
                            forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("DeepL-Auth-Key \(key)", forHTTPHeaderField: "Authorization")

        var components = URLComponents()
        components.queryItems = [
            URLQueryItem(name: "text", value: request.text),
            URLQueryItem(name: "target_lang", value: "ZH"),
            URLQueryItem(name: "source_lang", value: "EN")
        ]
        urlRequest.httpBody = components.percentEncodedQuery?.data(using: .utf8)

        let data = try await perform(urlRequest)

        guard
            let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let translations = root["translations"] as? [[String: Any]],
            let translated = translations.first?["text"] as? String
        else {
            throw AnalysisError.malformedResponse("DeepL 返回内容无法识别。")
        }

        var result = AnalysisResult(original: request.text, kind: .sentence)
        result.sentence = SentenceAnalysis(translation: translated)
        result.engine = "DeepL"
        return result
    }

    // MARK: - 通用

    private func perform(_ request: URLRequest) async throws -> Data {
        let pair: (Data, URLResponse)
        do {
            pair = try await session.data(for: request)
        } catch let error as URLError where error.code == .cancelled {
            throw AnalysisError.cancelled
        } catch let error as URLError {
            throw AnalysisError.network(error.localizedDescription)
        } catch {
            throw AnalysisError.network(error.localizedDescription)
        }
        let data = pair.0
        let response = pair.1

        guard let http = response as? HTTPURLResponse else {
            throw AnalysisError.network("没有收到有效的 HTTP 响应。")
        }

        guard (200..<300).contains(http.statusCode) else {
            let message = String(data: data.prefix(600), encoding: .utf8) ?? ""
            throw AnalysisError.server(status: http.statusCode, message: message)
        }

        return data
    }

    func decodeResult(from rawContent: String, request: AnalysisRequest, engineName: String) throws -> AnalysisResult {
        guard let payload = ModelOutputParser.parse(rawContent, expected: request.kind) else {
            throw AnalysisError.malformedResponse(String(rawContent.prefix(200)))
        }

        var result = AnalysisResult(original: request.text, kind: payload.kind ?? request.kind)
        result.word = payload.word
        result.sentence = payload.sentence
        result.engine = engineName

        if result.word == nil && result.sentence == nil {
            throw AnalysisError.malformedResponse("模型没有返回可展示的字段。")
        }
        // 保底：让界面总能显示点东西。
        if result.sentence?.translation.isEmpty ?? false, result.word == nil {
            result.sentence?.translation = rawContent
        }
        return result
    }
}

/// 模型输出解析：处理 ```json 包裹、前后多余文字、末尾逗号等常见瑕疵。
enum ModelOutputParser {
    static func parse(_ raw: String, expected: AnalysisKind) -> AnalysisPayload? {
        for candidate in candidates(from: raw) {
            if let payload = decode(candidate) {
                return payload
            }
        }
        return nil
    }

    static func parseLesson(_ raw: String) -> Lesson? {
        for candidate in candidates(from: raw) {
            if let lesson = decodeLesson(candidate) {
                return lesson
            }
        }
        return nil
    }

    static func decodeLesson(_ text: String) -> Lesson? {
        guard let data = text.data(using: .utf8) else { return nil }
        let decoder = JSONDecoder()
        if let lesson = try? decoder.decode(Lesson.self, from: data), !lesson.blocks.isEmpty {
            return lesson
        }
        if let envelope = try? decoder.decode(LessonEnvelope.self, from: data),
           let lesson = envelope.lesson, !lesson.blocks.isEmpty {
            return lesson
        }

        let sanitized = removeTrailingCommas(text)
        guard sanitized != text, let fixed = sanitized.data(using: .utf8) else { return nil }
        if let lesson = try? decoder.decode(Lesson.self, from: fixed), !lesson.blocks.isEmpty {
            return lesson
        }
        if let envelope = try? decoder.decode(LessonEnvelope.self, from: fixed),
           let lesson = envelope.lesson, !lesson.blocks.isEmpty {
            return lesson
        }
        return nil
    }

    static func candidates(from raw: String) -> [String] {
        var results: [String] = []
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        results.append(trimmed)

        // ```json ... ```
        if let start = trimmed.range(of: "```") {
            var body = trimmed[start.upperBound...]
            if body.hasPrefix("json") {
                body = body.dropFirst(4)
            }
            if let end = body.range(of: "```") {
                results.append(String(body[..<end.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines))
            }
        }

        // 从第一个 { 到最后一个 }
        if let first = trimmed.firstIndex(of: "{"), let last = trimmed.lastIndex(of: "}"), first < last {
            results.append(String(trimmed[first...last]))
        }

        return results
    }

    static func decode(_ text: String) -> AnalysisPayload? {
        guard let data = text.data(using: .utf8) else { return nil }
        let decoder = JSONDecoder()
        if let payload = try? decoder.decode(AnalysisPayload.self, from: data) {
            return payload
        }

        let sanitized = removeTrailingCommas(text)
        if sanitized != text,
           let data = sanitized.data(using: .utf8),
           let payload = try? decoder.decode(AnalysisPayload.self, from: data) {
            return payload
        }
        return nil
    }

    /// 去掉 `,}` 和 `,]` 这类尾逗号。
    static func removeTrailingCommas(_ text: String) -> String {
        var output = ""
        output.reserveCapacity(text.count)
        let characters = Array(text)
        var index = 0
        while index < characters.count {
            let character = characters[index]
            if character == "," {
                var lookahead = index + 1
                while lookahead < characters.count, characters[lookahead].isWhitespace {
                    lookahead += 1
                }
                if lookahead < characters.count, characters[lookahead] == "}" || characters[lookahead] == "]" {
                    index += 1
                    continue
                }
            }
            output.append(character)
            index += 1
        }
        return output
    }
}
