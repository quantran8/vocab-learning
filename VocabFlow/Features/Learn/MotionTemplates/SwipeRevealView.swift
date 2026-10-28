import SwiftUI

/// A single left-to-right clipping mask reveals the whole word, led by a blue edge.
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
            .overlay(alignment: .leading) {
                GeometryReader { proxy in
                    Capsule()
                        .fill(Color.interactive)
                        .frame(width: 4)
                        .offset(x: isRevealed ? proxy.size.width : 0)
                        .animation(MotionTokens.introSweep, value: isRevealed)
                        .opacity(isRevealed ? 0 : 1)
                        .animation(MotionTokens.introReveal.delay(0.7), value: isRevealed)
                }
            }
            .onAppear { isRevealed = true }
    }
}
