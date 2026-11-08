import Foundation

enum LLMProvider: String, Codable, CaseIterable, Identifiable, Sendable {
    case deepSeek
    case openAI
    case anthropic
    case compatible
    case deepL

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .deepSeek: return "DeepSeek"
        case .openAI: return "OpenAI（ChatGPT 接口）"
        case .anthropic: return "Claude（Anthropic）"
        case .compatible: return "兼容 OpenAI 的自建服务"
        case .deepL: return "DeepL（仅翻译）"
        }
    }

    var shortName: String {
        switch self {
        case .deepSeek: return "DeepSeek"
        case .openAI: return "OpenAI"
        case .anthropic: return "Claude"
        case .compatible: return "自定义"
        case .deepL: return "DeepL"
        }
    }

    var defaultModel: String {
        switch self {
        case .deepSeek: return "deepseek-flash"
        case .openAI: return "gpt-5-mini"
        case .anthropic: return "claude-3-5-haiku-latest"
        case .compatible: return "qwen-plus"
        case .deepL: return ""
        }
    }

    var defaultBaseURL: String {
        switch self {
        case .deepSeek: return "https://api.deepseek.com"
        case .openAI: return "https://api.openai.com/v1"
        case .anthropic: return "https://api.anthropic.com"
        case .compatible: return "http://192.168.1.10:11434/v1"
        case .deepL: return "https://api-free.deepl.com"
        }
    }

    /// 只有确认支持 response_format=json_object 的服务才加这个字段。
    var supportsJSONMode: Bool {
        switch self {
        case .openAI, .deepSeek: return true
        case .anthropic, .compatible, .deepL: return false
        }
    }

    var supportsStructuredAnalysis: Bool {
        self != .deepL
    }

    var apiKeyPlaceholder: String {
        switch self {
        case .deepSeek: return "sk-…（platform.deepseek.com 创建）"
        case .openAI: return "sk-…（platform.openai.com 创建）"
        case .anthropic: return "sk-ant-…（console.anthropic.com 创建）"
        case .compatible: return "本地服务可留空"
        case .deepL: return "DeepL Auth Key，免费版以 :fx 结尾"
        }
    }

    /// 设置页模型输入框下面的提示：报 model not found 时照着换一个。
    var modelHint: String {
        switch self {
        case .deepSeek: return "常用：deepseek-flash（快、便宜）、deepseek-v4-pro（更强）"
        case .openAI: return "常用：gpt-5-mini、gpt-5。名字以 platform.openai.com/docs/models 为准"
        case .anthropic: return "常用：claude-sonnet-4-5、claude-haiku-4-5。名字以官方文档为准"
        case .compatible: return "填你的服务实际提供的模型名，例如 qwen-plus、kimi-k2"
        case .deepL: return "DeepL 不用模型名，留空即可"
        }
    }

    var notes: String {
        switch self {
        case .deepSeek:
            return "中文解释质量好、价格低，国内可直接访问，推荐作为默认方案。"
        case .openAI:
            return "ChatGPT 网页版和 App 的免费版没有 API，想用它得在 platform.openai.com 单独充钱（最低 5 美元）。JSON 输出最稳，解释也细；国内需要能访问 OpenAI 的网络环境。"
        case .anthropic:
            return "长句语法讲解细腻，价格高于 mini 系列；需要海外网络环境。"
        case .compatible:
            return "任何兼容 /v1/chat/completions 的服务都可以，例如 Ollama、LM Studio、通义、Kimi。"
        case .deepL:
            return "只能翻译，给不出音标、搭配和语法解析，不建议作为主方案。"
        }
    }
}

struct EngineSettings: Codable, Equatable, Sendable {
    var provider: LLMProvider = .deepSeek
    var apiKey: String = ""
    var model: String = ""
    var baseURL: String = ""
    var offlineFallbackEnabled: Bool = true

    var resolvedModel: String {
        let trimmed = model.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? provider.defaultModel : trimmed
    }

    var resolvedBaseURL: URL? {
        var raw = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        if raw.isEmpty {
            if provider == .deepL {
                raw = apiKey.hasSuffix(":fx") ? "https://api-free.deepl.com" : "https://api.deepl.com"
            } else {
                raw = provider.defaultBaseURL
            }
        }
        if raw.hasSuffix("/") {
            raw = String(raw.dropLast())
        }
        guard let url = URL(string: raw), let scheme = url.scheme, scheme.hasPrefix("http") else {
            return nil
        }
        return url
    }

    var requiresAPIKey: Bool {
        provider != .compatible
    }

    var isConfigured: Bool {
        if requiresAPIKey && apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return false
        }
        return resolvedBaseURL != nil
    }
}

enum SettingsStore {
    private static let key = "fathom.engine.settings.v1"

    static func load() -> EngineSettings {
        guard let data = SharedStorage.defaults.data(forKey: key) else {
            return EngineSettings()
        }
        return (try? JSONDecoder().decode(EngineSettings.self, from: data)) ?? EngineSettings()
    }

    static func save(_ settings: EngineSettings) {
        guard let data = try? JSONEncoder().encode(settings) else { return }
        SharedStorage.defaults.set(data, forKey: key)
    }

    static func reset() {
        SharedStorage.defaults.removeObject(forKey: key)
    }
}
