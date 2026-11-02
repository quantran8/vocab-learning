import SwiftUI

/// `select`. Options keep the backend's order; their ids aren't positions.
struct ChoiceTaskView: View {
    let attempt: TaskAttempt
    @Environment(PracticeSessionStore.self) private var store
    @State private var selectedID: Int?

    var body: some View {
        TaskScaffold(attempt: attempt) {
            if case .choice(let options, _, let correct) = attempt.task.body {
                VStack(spacing: Spacing.s) {
                    ForEach(options) { option in
                        ChoiceTileButton(text: option.text, state: state(option.id, correct: correct)) {
                            selectedID = selectedID == option.id ? nil : option.id
                            store.answerPicked()
                        }
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
    }

    private func state(_ id: Int, correct: Int) -> WordTileVisualState {
        if attempt.status == .exhausted { return attempt.lastWrongOptionID == id ? .incorrect : .disabled }
        if attempt.isFinished { return id == correct ? .correct : .disabled }
        if attempt.status == .wrong, attempt.lastWrongOptionID == id { return .incorrect }
        return selectedID == id ? .selected : .idle
    }
}
