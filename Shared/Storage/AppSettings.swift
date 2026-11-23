import Foundation

/// 一些「用起来顺不顺手」的偏好，和引擎配置分开存。
///
/// 之所以单独放，是因为这些设置不涉及 API Key，扩展用不到，
/// 放在 EngineSettings 里只会让那坨 JSON 越来越难懂。
enum AppSettings {
    private static var defaults: UserDefaults { SharedStorage.defaults }

    private enum Key {
        static let reviewBatchSize = "fathom.prefs.reviewBatchSize"
        static let collapseTranslation = "fathom.prefs.collapseTranslation"
    }

    /// 一次复习多少张卡。
    static var reviewBatchSize: Int {
        get {
            let value = defaults.integer(forKey: Key.reviewBatchSize)
            return value == 0 ? 10 : value
        }
        set { defaults.set(newValue, forKey: Key.reviewBatchSize) }
    }

    /// 打开卡片时是否先把译文藏起来（先自己回想一遍）。
    static var collapseTranslation: Bool {
        get {
            if defaults.object(forKey: Key.collapseTranslation) == nil { return true }
            return defaults.bool(forKey: Key.collapseTranslation)
        }
        set { defaults.set(newValue, forKey: Key.collapseTranslation) }
    }
}
