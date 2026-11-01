import SwiftUI

struct TypingTaskView: View {
    let attempt: TaskAttempt
    @Environment(PracticeSessionStore.self) private var store
    @State private var text = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        TaskScaffold(attempt: attempt) {
            RecallInput(text: $text, isFocused: $isFocused, isEnabled: attempt.status == .answering, onSubmit: check)
        } action: {
            VStack(spacing: 0) {
                if attempt.status == .answering {
                    HintControl(
                        hintsUsed: attempt.hintsUsed,
                        maxHints: TaskAttempt.maxHints,
                        hints: attempt.hints,
                        isEnabled: true,
                        canReveal: attempt.canReveal,
                        onHint: { store.useHint() },
                        onReveal: {
                            store.reveal()
                            isFocused = false
                        }
                    )
                }
                TaskActionBar(attempt: attempt, canCheck: canCheck, onCheck: check, showsReveal: false)
            }
        }
        .onChange(of: attempt.status) { _, status in
            if status != .answering {
                isFocused = false
            } else {
                text = ""
                isFocused = true
            }
        }
    }

    private var canCheck: Bool { !PracticeAnswer.normalize(text).isEmpty }

    private func check() {
        guard canCheck else { return }
        store.submitText(text)
    }
}
