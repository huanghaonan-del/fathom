import SwiftUI

/// 一个小喇叭按钮：点一下把英文读出来。
struct SpeakerButton: View {
    let text: String
    var compact: Bool = false

    var body: some View {
        Button {
            SpeechService.speak(text)
        } label: {
            Image(systemName: "speaker.wave.2.fill")
                .font(.system(size: compact ? 11 : 13, weight: .semibold))
                .foregroundStyle(Color.accentColor)
                .frame(width: compact ? 24 : 30, height: compact ? 24 : 30)
                .background(Color.accentColor.opacity(0.10), in: Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("朗读")
        .accessibilityHint(text)
    }
}
