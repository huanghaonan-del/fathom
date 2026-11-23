import AVFoundation
import Foundation

/// 朗读设置：用哪个声音、读多快。
///
/// 存在 App Group 的 UserDefaults 里，主 App 和扩展读同一份。
enum SpeechSettings {
    private static let key = "fathom.speech.settings.v1"

    struct Values: Codable, Equatable {
        /// 空字符串 = 自动挑最好的声音
        var voiceIdentifier: String = ""
        /// 0.35 慢 … 0.52 正常稍慢
        var rate: Double = 0.46
    }

    static func load() -> Values {
        guard let data = SharedStorage.defaults.data(forKey: key),
              let values = try? JSONDecoder().decode(Values.self, from: data) else {
            return Values()
        }
        return values
    }

    static func save(_ values: Values) {
        guard let data = try? JSONEncoder().encode(values) else { return }
        SharedStorage.defaults.set(data, forKey: key)
    }
}

/// 把英文读出来。
///
/// 用的是系统 `AVSpeechSynthesizer`：不联网、不花钱、支持后台播放。
/// 想听到「有感情的美式英语」，关键不是代码，而是设备上装了哪个声音：
/// 设置 → 辅助功能 → 朗读内容 → 声音 → 英语（美国）→ 下载 Ava / Samantha 的「高级」版，
/// 下载完回到 Fathom 设置里选中即可。
enum SpeechService {
    private static let synthesizer = AVSpeechSynthesizer()

    static var isSpeaking: Bool { synthesizer.isSpeaking }

    static func stop() {
        synthesizer.stopSpeaking(at: .immediate)
    }

    static func speak(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }

        let utterance = AVSpeechUtterance(string: trimmed)
        utterance.voice = preferredVoice()
        utterance.rate = Float(SpeechSettings.load().rate)
        utterance.pitchMultiplier = 1.0
        utterance.preUtteranceDelay = 0
        utterance.postUtteranceDelay = 0

        // 用 playback + duckOthers：压低背景音乐而不是把它掐断，
        // 这样在听歌时点朗读不会把音乐关掉。
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers, .mixWithOthers])
        try? session.setActive(true, options: [])

        synthesizer.speak(utterance)
    }

    // MARK: - 声音挑选

    /// 所有美式英语声音，质量高的排在前面。
    static func americanVoices() -> [AVSpeechSynthesisVoice] {
        AVSpeechSynthesisVoice.speechVoices()
            .filter { $0.language == "en-US" }
            .sorted { qualityRank($0) > qualityRank($1) }
    }

    /// 用户选过的优先；没选过就自动挑最好的女声（Ava 那一类）。
    static func preferredVoice() -> AVSpeechSynthesisVoice? {
        let values = SpeechSettings.load()
        if !values.voiceIdentifier.isEmpty,
           let chosen = AVSpeechSynthesisVoice(identifier: values.voiceIdentifier) {
            return chosen
        }

        let voices = americanVoices()
        if let bestFemale = voices.first(where: { qualityRank($0) >= 2 && $0.gender == .female }) {
            return bestFemale
        }
        if let best = voices.first {
            return best
        }
        return AVSpeechSynthesisVoice(language: "en-US")
    }

    static func qualityRank(_ voice: AVSpeechSynthesisVoice) -> Int {
        switch voice.quality {
        case .premium: return 3
        case .enhanced: return 2
        default: return 1
        }
    }

    static func qualityName(_ voice: AVSpeechSynthesisVoice) -> String {
        switch voice.quality {
        case .premium: return "高级"
        case .enhanced: return "增强"
        default: return "标准"
        }
    }

    /// 设置页里显示用：名字 + 质量，例如「Ava（高级）」
    static func displayName(_ voice: AVSpeechSynthesisVoice) -> String {
        let quality = qualityName(voice)
        return "\(voice.name)（\(quality)）"
    }
}
