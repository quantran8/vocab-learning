import SwiftUI

/// Letters rise one by one onto a blue baseline.
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
        .overlay(alignment: .bottom) {
            Capsule()
                .fill(Color.interactive)
                .frame(height: 4)
                .scaleEffect(x: isRevealed ? 1 : 0, anchor: .leading)
                .offset(y: 8)
                .animation(MotionTokens.introSweep, value: isRevealed)
        }
        .onAppear { isRevealed = true }
    }
}
