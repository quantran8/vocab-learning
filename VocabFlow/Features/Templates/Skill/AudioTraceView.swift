import SwiftUI

/// Listen and spell. Replays are tracked as assistance; reveal shows the spelling on request.
struct AudioTraceView: View {
    let run: TemplateRun
    @Environment(TemplateSandboxStore.self) private var sandbox
    @State private var text = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        TemplateFrame(run: run) {
            VStack(spacing: Spacing.l) {
                AudioCuePanel(run: run, fallbackClue: "\(run.word.meaningVi)\n\(run.word.ipa ?? "")", isLarge: true)

                RecallInput(text: $text, isFocused: $isFocused, isEnabled: !run.phase.isFinished && run.phase != .incorrect) { check() }

                if run.phase.isFinished {
                    Text("Spelling: \(run.word.term) · listened \(run.audioPlayCount)×")
                        .font(Typography.secondary.weight(.semibold))
                        .foregroundStyle(Color.mutedInk)
                } else {
                    Button("Show spelling") {
                        sandbox.reveal()
                        isFocused = false
                    }
                    .font(Typography.secondary.weight(.bold))
                    .foregroundStyle(Color.mutedInk)
                    .frame(minHeight: Spacing.minTouchTarget)
                }
            }
        } action: {
            TemplateActionBar(
                run: run,
                canCheck: canCheck,
                requirement: "Type the word you heard.",
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
