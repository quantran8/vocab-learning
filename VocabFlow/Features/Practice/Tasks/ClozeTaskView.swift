import SwiftUI

/// `clozeSelect`: a word bank like reorder, and the picked word flies into the blank.
/// Options keep the backend's order; their ids aren't positions.
struct ClozeTaskView: View {
    let attempt: TaskAttempt
    @Environment(PracticeSessionStore.self) private var store
    @Environment(\.motion) private var motion
    @Namespace private var flightSpace
    @State private var selectedID: Int?

    var body: some View {
        TaskScaffold(attempt: attempt) {
            if case .choice(let options, let sentence?, let correct) = attempt.task.body {
                let filledID = filledOptionID(correct: correct)
                VStack(spacing: Spacing.l) {
                    ClozeSentence(
                        parts: sentence,
                        filled: options.first { $0.id == filledID },
                        filledState: filledState,
                        flightSpace: flightSpace,
                        onRemove: remove
                    )
                    // Above the bank, so a word leaving for the blank isn't drawn under the gray slots.
                    .zIndex(1)
                    FlowLayout(spacing: Spacing.xs, lineSpacing: Spacing.xs) {
                        ForEach(options) { option in
                            bankSlot(option, filledID: filledID)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                .animation(motion.travel(MotionTokens.snap), value: filledID)
            }
        } action: {
            TaskActionBar(attempt: attempt, canCheck: selectedID != nil) {
                guard let selectedID else { return }
                store.submitOption(selectedID)
                self.selectedID = nil
            }
        }
    }

    /// The word sitting in the blank. Nothing is sent until Check, so this is presentation only.
    private func filledOptionID(correct: Int) -> Int? {
        switch attempt.status {
        case .solved, .revealed: correct
        case .wrong, .exhausted: attempt.lastWrongOptionID
        default: selectedID
        }
    }

    private var filledState: WordTileVisualState {
        switch attempt.status {
        case .solved, .revealed: .correct
        case .wrong, .exhausted: .incorrect
        default: .selected
        }
    }

    private func remove() {
        guard attempt.status == .answering else { return }
        selectedID = nil
        store.haptics.selectionChanged()
    }

    private func bankTile(_ option: TaskOption) -> some View {
        let tileState: WordTileVisualState = attempt.isFinished ? .disabled : .idle
        return Button {
            selectedID = option.id
            store.haptics.selectionChanged()
        } label: {
            ClozeTile(text: option.text, state: tileState)
        }
        .buttonStyle(PressScaleButtonStyle())
        .disabled(tileState == .disabled)
        .matchedGeometryEffect(id: option.id, in: flightSpace)
        .accessibilityLabel(Text("\(option.text), option"))
    }

    /// Holds the word's place so the bank doesn't reflow. The gray stand-in sits under the tile rather than
    /// replacing it, so it stays until a returning word lands.
    private func bankSlot(_ option: TaskOption, filledID: Int?) -> some View {
        ClozeTile(text: option.text, state: .idle)
            .hidden()
            .background {
                RoundedRectangle(cornerRadius: Radii.chip, style: .continuous)
                    .fill(Color.stroke)
                    .padding(.bottom, Spacing.tileDepth)
            }
            .accessibilityHidden(true)
            .overlay {
                if option.id != filledID {
                    bankTile(option)
                }
            }
    }
}

/// A word tile in the reorder style, the same in the bank and in the blank.
private struct ClozeTile: View {
    let text: String
    let state: WordTileVisualState

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: Radii.chip, style: .continuous)
        Text(verbatim: text)
            .font(Typography.sentence)
            .foregroundStyle(ink)
            .padding(.horizontal, Spacing.s)
            .frame(minHeight: Spacing.minTouchTarget - Spacing.tileDepth)
            .background(surface, in: shape)
            .overlay(shape.strokeBorder(border, lineWidth: 1.5))
            .background(shape.fill(depth).offset(y: Spacing.tileDepth))
            .padding(.bottom, Spacing.tileDepth)
            .opacity(state == .disabled ? 0.6 : 1)
    }

    private var ink: Color {
        switch state {
        case .correct: Color.successInk
        case .incorrect: Color.errorInk
        case .selected: Color.selectedInk
        default: Color.ink
        }
    }

    private var surface: Color {
        switch state {
        case .correct: Color.successSurface
        case .incorrect: Color.errorSurface
        case .selected: Color.selectedSurface
        default: Color.surface
        }
    }

    private var depth: Color {
        switch state {
        case .correct: Color.successDepth
        case .incorrect: Color.errorDepth
        case .selected: Color.selectedDepth
        default: Color.tileDepth
        }
    }

    private var border: Color {
        switch state {
        case .correct: Color.success
        case .incorrect: Color.error
        case .selected: Color.interactive
        default: Color.stroke
        }
    }
}

/// The sentence as separate words, because the blank needs a real frame for the word to land in.
private struct ClozeSentence: View {
    let parts: SentenceParts
    let filled: TaskOption?
    let filledState: WordTileVisualState
    let flightSpace: Namespace.ID
    let onRemove: () -> Void

    private static let blankWidth: CGFloat = 72
    private static let wordSpacing = Spacing.xxs + 2

    var body: some View {
        let line = ClozeLine(parts)
        FlowLayout(spacing: Self.wordSpacing, lineSpacing: 0) {
            ForEach(Array(line.wordsBefore.enumerated()), id: \.offset) { word(in: $0.element) }
            HStack(spacing: 0) {
                word(in: line.attachedBefore)
                blank
                word(in: line.attachedAfter)
            }
            ForEach(Array(line.wordsAfter.enumerated()), id: \.offset) { word(in: $0.element) }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.m)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: parts.before + (filled?.text ?? String(localized: "blank")) + parts.after))
        .accessibilityAction(named: Text("Remove answer"), onRemove)
    }

    /// Every word takes the blank's height, so a line reads straight once a word lands.
    private func word(in text: String) -> some View {
        Text(verbatim: text)
            .font(Typography.sentence)
            .foregroundStyle(Color.ink)
            .frame(minHeight: Spacing.minTouchTarget)
    }

    @ViewBuilder private var blank: some View {
        if let filled {
            Button(action: onRemove) {
                ClozeTile(text: filled.text, state: filledState)
            }
            .buttonStyle(.plain)
            .matchedGeometryEffect(id: filled.id, in: flightSpace)
        } else {
            Rectangle()
                .fill(Color.interactive)
                .frame(width: Self.blankWidth, height: 2)
                .frame(minHeight: Spacing.minTouchTarget, alignment: .bottom)
        }
    }
}
