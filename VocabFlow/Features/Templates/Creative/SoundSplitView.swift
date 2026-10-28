import SwiftUI

/// Syllables are always displayed; audio supports the decision but is never the only instruction.
struct SoundSplitView: View {
    let run: TemplateRun
    @Environment(TemplateSandboxStore.self) private var sandbox
    @State private var selectedIndex: Int?

    var body: some View {
        let syllables = run.word.syllables

        TemplateFrame(run: run) {
            VStack(spacing: Spacing.l) {
                // No IPA here: its stress mark would give the answer away.
                AudioCuePanel(run: run, fallbackClue: String(localized: "Say “\(run.word.term)” to yourself and notice which part is longer and louder."))

                // Equal-width segments so no syllable looks visually "bigger" (i.e. stressed).
                HStack(spacing: Spacing.xs) {
                    ForEach(Array(syllables.enumerated()), id: \.offset) { index, syllable in
                        syllableButton(syllable, index: index, total: syllables.count)
                    }
                }

                if run.phase == .correct, let ipa = run.word.ipa {
                    Text(verbatim: ipa)
                        .font(Typography.body.weight(.semibold))
                        .foregroundStyle(Color.mutedInk)
                }
            }
        } action: {
            TemplateActionBar(
                run: run,
                canCheck: selectedIndex != nil && run.feedback != .wrongStress(index: selectedIndex ?? -1),
                requirement: "Tap the syllable you think is stressed.",
                onCheck: {
                    guard let selectedIndex else { return }
                    sandbox.submitStress(selectedIndex)
                    self.selectedIndex = nil
                }
            )
        }
    }

    private func syllableButton(_ syllable: String, index: Int, total: Int) -> some View {
        let state: WordTileVisualState
        if run.phase == .correct {
            state = index == run.word.stressIndex ? .correct : .disabled
        } else if selectedIndex == index {
            state = .selected
        } else if run.feedback == .wrongStress(index: index) {
            state = .incorrect
        } else {
            state = .idle
        }

        return Button {
            selectedIndex = selectedIndex == index ? nil : index
            sandbox.haptics.selectionChanged()
        } label: {
            WordTile(text: run.phase == .correct && index == run.word.stressIndex ? syllable.uppercased() : syllable, visualState: state)
        }
        .buttonStyle(.plain)
        .disabled(run.phase.isFinished)
        .accessibilityLabel(Text("Syllable \(index + 1) of \(total), \(syllable)"))
        .accessibilityValue(state == .selected ? Text("Selected") : (state == .correct ? Text("Stressed") : Text(verbatim: "")))
        .accessibilityAddTraits(state == .selected ? [.isSelected] : [])
    }
}
