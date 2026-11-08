import SwiftUI

struct TypingTaskView: View {
    let attempt: TaskAttempt
    @Environment(PracticeSessionStore.self) private var store
    @State private var text = ""
    @FocusState private var isFocused: Bool
    /// Set while Check waits for the keyboard to go down, so a second tap doesn't submit twice.
    @State private var isSubmitting = false
    @State private var submitTask: Task<Void, Never>?

    var body: some View {
        TaskScaffold(attempt: attempt, onTapOutside: { isFocused = false }) {
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
        .onDisappear { submitTask?.cancel() }
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

    /// Closes the keyboard first, then submits once it's down, so the feedback isn't fighting the keyboard animation.
    private func check() {
        guard canCheck, !isSubmitting else { return }
        guard isFocused else {
            store.submitText(text)
            return
        }
        isFocused = false
        isSubmitting = true
        // The attempt itself ignores the submit if "Show answer" was used meanwhile.
        submitTask = Task {
            try? await Task.sleep(for: .seconds(MotionTokens.keyboardDismiss))
            isSubmitting = false
            guard !Task.isCancelled else { return }
            store.submitText(text)
        }
    }
}
