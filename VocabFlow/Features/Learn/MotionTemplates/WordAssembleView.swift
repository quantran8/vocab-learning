import SwiftUI

/// Letters converge from short, deterministic offsets into the final black word.
struct WordAssembleView: View {
    let word: String
    @State private var isRevealed = false

    var body: some View {
        IntroGlyphRow(
            word: word,
            isRevealed: isRevealed,
            hidden: { index, _ in
                // Stable pseudo-scatter: same word, same offsets on every replay.
                let dx = CGFloat((index * 7) % 5 - 2) * 14
                let dy = CGFloat((index * 11) % 5 - 2) * 12
                return IntroGlyphStyle(offset: CGSize(width: dx, height: dy), scale: 0.7, opacity: 0)
            },
            animation: { index in MotionTokens.introLetter.delay(Double(index % 3) * 0.04) }
        )
        .onAppear { isRevealed = true }
    }
}
