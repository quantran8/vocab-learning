import SwiftUI

/// Letters arrive in a quick staggered bounce, then sit still. Yellow decorative corner.
struct LetterWaveView: View {
    let word: String
    @State private var isRevealed = false

    var body: some View {
        IntroGlyphRow(
            word: word,
            isRevealed: isRevealed,
            hidden: { _, _ in IntroGlyphStyle(offset: CGSize(width: 0, height: -22), scale: 0.6, opacity: 0) },
            animation: { index in MotionTokens.introBounce.delay(Double(index) * 0.05) }
        )
        .overlay(alignment: .topTrailing) {
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(Color.reward)
                .frame(width: 12, height: 12)
                .rotationEffect(.degrees(45))
                .scaleEffect(isRevealed ? 1 : 0)
                .offset(x: 16, y: -8)
                .animation(MotionTokens.introAccent.delay(0.35), value: isRevealed)
        }
        .onAppear { isRevealed = true }
    }
}
