import SwiftUI

/// Two-step repair: locate the wrong grapheme, then choose the replacement that spells the target.
struct LetterSurgeryView: View {
    let run: TemplateRun
    @Environment(TemplateSandboxStore.self) private var sandbox
    @State private var selectedIndex: Int?
    @State private var selectedReplacement: String?

    var body: some View {
        let letters = run.exercise.misspellingLetters

        TemplateFrame(run: run) {
            VStack(spacing: Spacing.l) {
                FlowLayout(spacing: Spacing.xs, lineSpacing: Spacing.xs) {
                    ForEach(Array(letters.enumerated()), id: \.offset) { index, letter in
                        letterBox(displayed(letter, at: index), index: index, total: letters.count)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, Spacing.l)

                if run.locatedLetterIndex != nil {
                    VStack(spacing: Spacing.s) {
                        Eyebrow(text: "Replace with")
                        HStack(spacing: Spacing.s) {
                            ForEach(run.exercise.replacementChoices ?? [], id: \.self) { option in
                                replacementButton(option)
                            }
                        }
                    }
                    .transition(.opacity)
                }
            }
        } action: {
            if run.locatedLetterIndex == nil {
                TemplateActionBar(
                    run: run,
                    checkTitle: "Check letter",
                    canCheck: selectedIndex != nil && run.feedback != .wrongLetter(index: selectedIndex ?? -1),
                    onCheck: {
                        guard let selectedIndex else { return }
                        sandbox.locateLetter(at: selectedIndex)
                        self.selectedIndex = nil
                    }
                )
            } else {
                TemplateActionBar(
                    run: run,
                    checkTitle: "Check fix",
                    canCheck: selectedReplacement != nil && run.feedback != .wrongRepair(selectedReplacement ?? ""),
                    onCheck: {
                        guard let selectedReplacement else { return }
                        sandbox.repairLetter(with: selectedReplacement)
                        self.selectedReplacement = nil
                    }
                )
            }
        }
    }

    private func displayed(_ letter: Character, at index: Int) -> String {
        if run.phase == .correct, index == run.locatedLetterIndex, let fix = run.exercise.replacementCharacter {
            return fix
        }
        return String(letter)
    }

    private func letterBox(_ letter: String, index: Int, total: Int) -> some View {
        let isLocated = run.locatedLetterIndex == index
        let isSelected = selectedIndex == index
        let isWrongPick = run.feedback == .wrongLetter(index: index)
        let fill: Color = run.phase == .correct ? .successSurface : (isLocated || isSelected ? .reward : .surface)
        let border: Color = run.phase == .correct ? .success : (isWrongPick ? .error : (isLocated ? .ink : (isSelected ? .ink : .stroke)))
        let shape = RoundedRectangle(cornerRadius: Radii.chip, style: .continuous)

        return Button {
            guard run.locatedLetterIndex == nil, !run.phase.isFinished else { return }
            selectedIndex = selectedIndex == index ? nil : index
            sandbox.haptics.selectionChanged()
        } label: {
            Text(verbatim: letter)
                .font(.system(.title2, design: .monospaced, weight: .bold))
                .foregroundStyle(run.phase == .correct ? Color.successInk : (isWrongPick ? Color.errorInk : Color.ink))
                .frame(minWidth: Spacing.minTouchTarget, minHeight: 52)
                .background(fill, in: shape)
                .overlay(shape.strokeBorder(border, lineWidth: isSelected || isLocated || isWrongPick ? 2 : 1.5))
                .background(shape.fill(Color.tileDepth).offset(y: Spacing.tileDepth))
                .padding(.bottom, Spacing.tileDepth)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("Letter \(index + 1) of \(total), \(letter)"))
        .accessibilityValue(isLocated ? Text("Marked as wrong") : (isSelected ? Text("Selected") : (isWrongPick ? Text("Checked, spelled correctly") : Text(verbatim: ""))))
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    private func replacementButton(_ option: String) -> some View {
        let isSelected = selectedReplacement == option
        let isWrong = run.feedback == .wrongRepair(option)
        let isFixed = run.phase == .correct && option == run.exercise.replacementCharacter
        let state: WordTileVisualState = isFixed ? .correct : (isSelected ? .selected : (isWrong ? .incorrect : (run.phase.isFinished ? .disabled : .idle)))
        return Button {
            selectedReplacement = isSelected ? nil : option
            sandbox.haptics.selectionChanged()
        } label: {
            WordTile(text: option, visualState: state)
                .frame(width: 72)
        }
        .buttonStyle(.plain)
        .disabled(run.phase.isFinished)
        .accessibilityLabel(Text("Replace with \(option)"))
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}
