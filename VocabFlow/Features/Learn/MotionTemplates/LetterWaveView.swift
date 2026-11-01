import SwiftUI

/// Letters arrive in a quick staggered bounce, then sit still.
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
        .onAppear { isRevealed = true }
    }
}
