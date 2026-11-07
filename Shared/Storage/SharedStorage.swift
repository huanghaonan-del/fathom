import Foundation

enum AppConfig {
    /// 显示名称，改这里即可同时改界面标题。
    static let appName = "Fathom"

    /// App Group 标识。改 bundle id 时，这里和两个 entitlements 文件要一起改。
    static let appGroupID = "group.com.fathomapp.fathom"

    static let supportDirectoryName = "FathomShared"
    static let vocabularyFileName = "vocabulary.json"

    /// 单条选中内容的最大长度，避免误选整章内容导致 token 爆掉。
    static let maxInputLength = 1200
}

/// 主 App 与 Action Extension 共享数据的统一入口。
///
/// 有 App Group 时用共享容器；没有时（例如免费账号未开通该能力）
/// 自动降级到各自沙盒内的 Application Support 目录，功能仍可用，只是两边不同步。
enum SharedStorage {
    static let defaults: UserDefaults = UserDefaults(suiteName: AppConfig.appGroupID) ?? .standard

    static var containerURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: AppConfig.appGroupID)
    }

    static var isUsingAppGroup: Bool {
        containerURL != nil
    }

    static var dataDirectory: URL {
        let base: URL
        if let containerURL {
            base = containerURL
        } else if let applicationSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            base = applicationSupport
        } else {
            base = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        }

        let directory = base.appendingPathComponent(AppConfig.supportDirectoryName, isDirectory: true)
        if !FileManager.default.fileExists(atPath: directory.path) {
            try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        }
        return directory
    }

    static var storageWarning: String? {
        isUsingAppGroup ? nil : "没有检测到 App Group 共享容器：主 App 与扩展的设置、生词本不会同步。"
    }
}
