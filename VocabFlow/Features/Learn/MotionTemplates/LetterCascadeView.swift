import SwiftUI

/// Letters rise one by one into place.
struct LetterCascadeView: View {
    let word: String
    @State private var isRevealed = false

    var body: some View {
        IntroGlyphRow(
            word: word,
            isRevealed: isRevealed,
            hidden: { _, _ in IntroGlyphStyle(offset: CGSize(width: 0, height: 26), opacity: 0) },
            animation: { index in MotionTokens.introLetter.delay(Double(index) * MotionTokens.introLetterStagger) }
        )
        .onAppear { isRevealed = true }
    }
}
