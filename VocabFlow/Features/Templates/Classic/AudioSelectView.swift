import SwiftUI

struct AudioSelectView: View {
    let run: TemplateRun
    @Environment(TemplateSandboxStore.self) private var sandbox
    @State private var selectedID: String?

    var body: some View {
        TemplateFrame(run: run) {
            VStack(spacing: Spacing.l) {
                AudioCuePanel(run: run, fallbackClue: fallbackClue, isLarge: true)

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

    /// IPA and English definition stand in for the sound without spelling the answer.
    private var fallbackClue: String? {
        [run.word.ipa, run.word.definitionEN.map { "“\($0)”" }].compactMap { $0 }.joined(separator: "\n")
    }
}
