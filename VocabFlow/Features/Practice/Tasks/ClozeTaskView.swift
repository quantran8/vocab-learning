import SwiftUI

/// `clozeSelect`: a word bank like reorder, and the picked word flies into the blank.
/// Options keep the backend's order; their ids aren't positions.
struct ClozeTaskView: View {
    let attempt: TaskAttempt
    @Environment(PracticeSessionStore.self) private var store
    @Environment(\.motion) private var motion
    @State private var selectedID: Int?
    @State private var lastFlight: Date?

    var body: some View {
        TaskScaffold(attempt: attempt) {
            if case .choice(let options, let sentence?, let correct) = attempt.task.body {
                let filledID = filledOptionID(correct: correct)
                VStack(spacing: Spacing.l) {
                    ClozeSentence(
                        parts: sentence,
                        filled: options.first { $0.id == filledID },
                        onRemove: remove
                    )
                    FlowLayout(spacing: Spacing.xs, lineSpacing: Spacing.xs) {
                        ForEach(options) { option in
                            bankSlot(option)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                // Above both the sentence and the bank, so a flying word is never drawn under either.
                // Placed from anchors inside this stack, so the step's entrance moves them with it and they never fly in.
                .overlayPreferenceValue(ClozeFramesKey.self) { frames in
                    GeometryReader { proxy in
                        ForEach(options) { option in
                            let isFilled = option.id == filledID
                            if let anchor = frames[isFilled ? .blank : .slot(option.id)] {
                                let frame = proxy[anchor]
                                // Only the position follows the frame. A word is the same size in the bank and
                                // in the blank, so taking the blank's width as well could only stretch it mid-flight.
                                tile(option, isFilled: isFilled)
                                    .position(x: frame.midX, y: frame.midY)
                            }
                        }
                    }
                }
                .animation(motion.travel(MotionTokens.wordFlight), value: filledID)
            }
        } action: {
            TaskActionBar(attempt: attempt, canCheck: selectedID != nil) {
                guard let selectedID else { return }
                store.submitOption(selectedID)
                self.selectedID = nil
            }
        }
        // "Try again" sends the wrong word back to the bank.
        .onChange(of: attempt.status) {
            if attempt.status == .answering { lastFlight = .now }
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

    /// Words ignore taps while any word is in the air, so a double-tap can't send one straight back.
    private func tap(_ option: TaskOption, isFilled: Bool) {
        if let lastFlight, Date.now.timeIntervalSince(lastFlight) < MotionTokens.wordFlightSettle { return }
        lastFlight = .now
        isFilled ? remove() : pick(option.id)
    }

    /// A word already in the blank flies home while the new one flies in.
    private func pick(_ id: Int) {
        guard attempt.status == .answering else { return }
        selectedID = id
        store.answerPicked()
    }

    private func remove() {
        guard attempt.status == .answering else { return }
        selectedID = nil
        store.answerPicked()
    }

    /// Each word is one view for the whole task, and flying only changes which frame it is placed on.
    /// Nothing is inserted or removed, so no fading copy of a word is left behind to catch the next move.
    private func tile(_ option: TaskOption, isFilled: Bool) -> some View {
        let tileState: WordTileVisualState = isFilled ? filledState : (attempt.isFinished ? .disabled : .idle)
        return Button {
            tap(option, isFilled: isFilled)
        } label: {
            ClozeTile(text: option.text, state: tileState)
        }
        .buttonStyle(PressScaleButtonStyle())
        .disabled(attempt.status != .answering)
        // The sentence reads the filled word and offers removing it.
        .accessibilityHidden(isFilled)
        .accessibilityLabel(Text("\(option.text), option"))
    }

    /// Holds the word's place so the bank doesn't reflow. The gray stand-in shows whenever the word is away.
    private func bankSlot(_ option: TaskOption) -> some View {
        ClozeTile(text: option.text, state: .idle)
            .hidden()
            .background {
                RoundedRectangle(cornerRadius: Radii.chip, style: .continuous)
                    .fill(Color.stroke)
                    .padding(.bottom, Spacing.tileDepth)
            }
            .accessibilityHidden(true)
            .anchorPreference(key: ClozeFramesKey.self, value: .bounds) { [.slot(option.id): $0] }
    }
}

/// The frames a word can sit in.
private enum ClozeFlightTarget: Hashable {
    case blank
    case slot(Int)
}

private struct ClozeFramesKey: PreferenceKey {
    static let defaultValue: [ClozeFlightTarget: Anchor<CGRect>] = [:]
    static func reduce(value: inout [ClozeFlightTarget: Anchor<CGRect>], nextValue: () -> [ClozeFlightTarget: Anchor<CGRect>]) {
        value.merge(nextValue()) { _, new in new }
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

    /// Always in place and only sized here: the word itself is drawn above, following this frame.
    private var blank: some View {
        ClozeTile(text: filled?.text ?? "", state: .idle)
            .hidden()
            .frame(width: filled == nil ? Self.blankWidth : nil)
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(Color.interactive)
                    .frame(height: 2)
                    .opacity(filled == nil ? 1 : 0)
            }
            .anchorPreference(key: ClozeFramesKey.self, value: .bounds) { [.blank: $0] }
    }
}
