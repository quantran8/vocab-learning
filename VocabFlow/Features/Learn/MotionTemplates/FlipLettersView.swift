import SwiftUI

/// Each letter rotates upright around its horizontal axis like a small tile.
struct FlipLettersView: View {
    let word: String
    @State private var isRevealed = false

    var body: some View {
        IntroGlyphRow(
            word: word,
            isRevealed: isRevealed,
            hidden: { _, _ in IntroGlyphStyle(opacity: 0, rotationX: -90) },
            animation: { index in MotionTokens.introLetter.delay(Double(index) * 0.06) }
        )
        .onAppear { isRevealed = true }
    }
}
