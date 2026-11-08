import SwiftUI

/// Syllie reacting to an answer: plays `reaction` once, then settles into `settledMood` (idle, or the held loop after
/// an intro like `deepThought`). Decorative only.
/// Looping moods (`thinking`) stay until the next reaction. A new reaction (or the same one after idle) restarts the cycle.
struct SyllieReactionView: View {
    let reaction: SyllieMood
    @State private var shown = SyllieMood.idle

    var body: some View {
        SyllieView(mood: shown)
            .task(id: reaction) {
                shown = reaction
                guard let duration = reaction.reactionDuration else { return }
                do {
                    try await Task.sleep(for: duration)
                } catch {
                    return
                }
                shown = reaction.settledMood
            }
    }
}

extension SyllieMood {
    /// How long the mood's one-shot animation in `syllie.riv` runs before Syllie can go back to idle.
    /// Nil for moods that loop and are held until the next one.
    var reactionDuration: Duration? {
        switch self {
        case .happy: .seconds(0.95)
        case .excited: .seconds(0.95)
        case .oops: .seconds(1.5)
        // Animation length plus the blend into the state.
        case .happyPop: .seconds(0.95)
        case .happyWiggle: .seconds(1.0)
        case .happyPuff: .seconds(1.0)
        case .happyFloat: .seconds(1.1)
        case .proud: .seconds(1.3)
        case .oopsSquish: .seconds(1.1)
        case .oopsWobble: .seconds(1.2)
        case .oopsFreeze: .seconds(1.4)
        case .oopsSlip: .seconds(1.35)
        case .sleepy: .zero
        case .wakeUp: .seconds(1.0)
        case .reviewReady: .seconds(1.05)
        case .reviewToLearn: .seconds(1.35)
        case .deepThought: .seconds(2.2)
        case .idle, .thinking, .breath, .reviewWatch, .deepThoughtHold: nil
        }
    }

    /// Where Syllie goes once the one-shot is over: the held loop for an intro, otherwise idle.
    var settledMood: SyllieMood {
        self == .deepThought ? .deepThoughtHold : .idle
    }
}
