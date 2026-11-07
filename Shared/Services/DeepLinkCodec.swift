import Foundation

/// 扩展与主 App 之间「不依赖 App Group」的兜底通道。
///
/// 免费 Apple ID 签名时 App Group 很可能拿不到（扩展与主 App 各用各的沙盒）。
/// 这种情况下扩展解析完的结果会编码进 `fathom://save?data=…`，
/// 由主 App 接收并写进生词本，保证查询历史不会丢。
enum DeepLinkCodec {
    static func saveURL(for result: AnalysisResult) -> URL? {
        let encoder = JSONEncoder()
        guard let data = try? encoder.encode(result) else { return nil }
        var components = URLComponents()
        components.scheme = "fathom"
        components.host = "save"
        components.queryItems = [URLQueryItem(name: "data", value: base64URLEncode(data))]
        return components.url
    }

    static func result(from url: URL) -> AnalysisResult? {
        guard url.scheme?.lowercased() == "fathom",
              url.host?.lowercased() == "save",
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let token = components.queryItems?.first(where: { $0.name == "data" })?.value,
              let data = base64URLDecode(token)
        else { return nil }

        return try? JSONDecoder().decode(AnalysisResult.self, from: data)
    }

    /// 有些宿主不允许扩展唤起主 App，这时扩展会把保存链接放进剪贴板，
    /// 用户打开 App 后从剪贴板粘回来。这里负责把那种「粘进来的链接」认出来。
    static func result(fromPastedText text: String) -> AnalysisResult? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.lowercased().hasPrefix("fathom://"),
              !trimmed.contains(where: { $0.isWhitespace }),
              let url = URL(string: trimmed)
        else { return nil }
        return result(from: url)
    }

    // base64url：去掉 + / =，避免 URL 里出现需要转义的字符。
    private static func base64URLEncode(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    private static func base64URLDecode(_ token: String) -> Data? {
        var value = token
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        while value.count % 4 != 0 { value += "=" }
        return Data(base64Encoded: value)
    }
}
