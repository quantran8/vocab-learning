import SwiftUI

/// Select Meaning, including the `meaningClash` variant (same UI and evaluator, closer distractors).
struct SelectMeaningView: View {
    let run: TemplateRun
    @Environment(TemplateSandboxStore.self) private var sandbox
    @State private var selectedID: String?

    var body: some View {
        TemplateFrame(run: run) {
            VStack(spacing: Spacing.l) {
                VStack(spacing: Spacing.xs) {
                    Text(verbatim: run.word.term)
                        .font(Typography.challengeTerm)
                        .foregroundStyle(Color.ink)
                    if let context = run.exercise.context {
                        Text(LearnView.highlight(run.word.term, in: context))
                            .font(Typography.body)
                            .foregroundStyle(Color.mutedInk)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, Spacing.l)

                VStack(spacing: Spacing.s) {
                    ForEach(run.exercise.choices ?? []) { choice in
                        ChoiceTileButton(text: choice.text, state: run.choiceState(choice.id, selected: selectedID)) {
                            selectedID = selectedID == choice.id ? nil : choice.id
                            sandbox.haptics.selectionChanged()
                        }
                    }
                }
            }
        } action: {
            TemplateActionBar(
                run: run,
                canCheck: selectedID != nil && selectedID != run.incorrectChoiceID,
                onCheck: {
                    guard let selectedID else { return }
                    sandbox.submitChoice(selectedID)
                    self.selectedID = nil
                }
            )
        }
    }
}
