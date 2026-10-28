import SwiftUI

/// Typed recall without choices. First try, hints, retries and reveal are recorded distinctly.
struct RecallTypingView: View {
    let run: TemplateRun
    @Environment(TemplateSandboxStore.self) private var sandbox
    @State private var text = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        TemplateFrame(run: run, instruction: "Type the English word.") {
            VStack(spacing: Spacing.l) {
                VStack(spacing: Spacing.s) {
                    Eyebrow(text: "Meaning")
                    Text(verbatim: run.word.meaningVi)
                        .font(Typography.challengeTerm)
                        .foregroundStyle(Color.ink)
                        .multilineTextAlignment(.center)
                    SentenceCard(sentence: run.exercise.prompt, answer: run.phase.isFinished ? run.word.term : nil)
                }

                RecallInput(text: $text, isFocused: $isFocused, isEnabled: !run.phase.isFinished && run.phase != .incorrect) { check() }

                HintControl(
                    hintsUsed: run.hintsUsed,
                    maxHints: run.hints.count,
                    hints: run.phase.isFinished ? [] : run.revealedHints,
                    isEnabled: !run.phase.isFinished && run.phase != .incorrect,
                    onHint: { sandbox.requestHint() },
                    onReveal: {
                        sandbox.reveal()
                        isFocused = false
                    }
                )
            }
        } action: {
            TemplateActionBar(
                run: run,
                canCheck: canCheck,
                requirement: "Type a word to check.",
                onCheck: check
            )
        }
        .onChange(of: sandbox.attemptToken) {
            text = ""
            isFocused = true
        }
        .onChange(of: run.phase) { _, phase in
            if phase == .incorrect || phase.isFinished { isFocused = false }
        }
    }

    private var canCheck: Bool {
        let submission = AnswerEvaluator.normalize(text)
        return !submission.isEmpty && run.feedback != .wrongTyped(submission)
    }

    private func check() {
        sandbox.submitText(text)
    }
}
