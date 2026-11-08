import SwiftUI

/// User-triggered pronunciation control. Never autoplays and never reveals the answer in its label.
struct AudioPlayButton: View {
    let isSpeaking: Bool
    let isAvailable: Bool
    var isLarge = false
    let action: () -> Void

    var body: some View {
        let size: CGFloat = isLarge ? 88 : 64
        Button(action: action) {
            icon
                .foregroundStyle(isAvailable ? Color.selectedInk : Color.disabledInk)
                .frame(width: size, height: size)
                .background(isAvailable ? Color.selectedSurface : Color.disabledSurface, in: Circle())
                .overlay(Circle().strokeBorder(isSpeaking ? Color.interactive : Color.clear, lineWidth: 2))
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(isAvailable ? "Play pronunciation" : "Audio unavailable"))
        .accessibilityValue(isSpeaking ? Text("Playing") : Text(verbatim: ""))
        .accessibilityHint(isAvailable ? Text("Replays the word. You can play it as often as you like.") : Text("Use the written clue instead."))
    }

    @ViewBuilder private var icon: some View {
        if isAvailable {
            SpeakerWaveIcon(isPlaying: isSpeaking, side: isLarge ? 44 : 32)
        } else {
            Image(systemName: "speaker.slash.fill")
                .font(.system(size: isLarge ? 34 : 24, weight: .bold))
        }
    }
}
