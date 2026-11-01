import SwiftUI

/// A single left-to-right clipping mask reveals the whole word.
struct SwipeRevealView: View {
    let word: String
    @State private var isRevealed = false

    var body: some View {
        Text(verbatim: word)
            .fixedSize()
            .mask(alignment: .leading) {
                Rectangle()
                    .scaleEffect(x: isRevealed ? 1 : 0, anchor: .leading)
                    .animation(MotionTokens.introSweep, value: isRevealed)
            }
            .onAppear { isRevealed = true }
    }
}
