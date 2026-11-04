import SwiftUI

/// `select`. Options keep the backend's order; their ids aren't positions.
struct ChoiceTaskView: View {
    let attempt: TaskAttempt
    @Environment(PracticeSessionStore.self) private var store
    @State private var selectedID: Int?
    /// Per option, so only the option just picked wrongly moves.
    @State private var shakes: [Int: CGFloat] = [:]
    @Environment(\.motion) private var motion

    var body: some View {
        TaskScaffold(attempt: attempt) {
            if case .choice(let options, _, let correct) = attempt.task.body {
                VStack(spacing: Spacing.s) {
                    ForEach(options) { option in
                        ChoiceTileButton(text: option.text, state: state(option.id, correct: correct)) {
                            selectedID = selectedID == option.id ? nil : option.id
                            store.answerPicked()
                        }
                        .modifier(ShakeEffect(animatableData: shakes[option.id, default: 0]))
                    }
                }
            }
        } action: {
            TaskActionBar(attempt: attempt, canCheck: selectedID != nil) {
                guard let selectedID else { return }
                store.submitOption(selectedID)
                self.selectedID = nil
            }
        }
        .onChange(of: attempt.status) { _, status in
            guard status == .wrong || status == .exhausted, let id = attempt.lastWrongOptionID else { return }
            withAnimation(motion.travel(MotionTokens.shake)) { shakes[id, default: 0] += 1 }
        }
    }

    private func state(_ id: Int, correct: Int) -> WordTileVisualState {
        if attempt.status == .exhausted { return attempt.lastWrongOptionID == id ? .incorrect : .disabled }
        if attempt.isFinished { return id == correct ? .correct : .disabled }
        if attempt.status == .wrong, attempt.lastWrongOptionID == id { return .incorrect }
        return selectedID == id ? .selected : .idle
    }
}
