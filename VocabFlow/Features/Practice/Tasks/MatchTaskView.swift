import SwiftUI

/// Tap one item on each side, in either order. Each pairing is sent as it happens; right pairs lock in.
struct MatchTaskView: View {
    let attempt: TaskAttempt
    @Environment(PracticeSessionStore.self) private var store
    @State private var selectedLeftID: Int?
    @State private var selectedRightID: Int?
    /// Tallest tile face seen so far; every tile uses it so both columns line up.
    @State private var tileHeight: CGFloat = Spacing.tileMinHeight
    /// The pair that just missed: both tiles show the error and shake briefly, then return to normal.
    @State private var flashingPair: PairKey?
    @State private var shakePhase: CGFloat = 0
    @State private var flashTask: Task<Void, Never>?
    @Environment(\.motion) private var motion

    var body: some View {
        TaskScaffold(attempt: attempt) {
            if case .match(let left, let right, let correct) = attempt.task.body {
                HStack(alignment: .top, spacing: Spacing.s) {
                    column(left, isLeft: true, correct: correct)
                    column(right, isLeft: false, correct: correct)
                }
            }
        } action: {
            TaskActionBar(attempt: attempt, requirement: "\(attempt.matchedLeftIDs.count) pairs matched")
        }
        .onChange(of: attempt.events.count) { flashWrongPair() }
        .onDisappear { flashTask?.cancel() }
    }

    private func flashWrongPair() {
        guard let wrong = attempt.lastWrongPair else { return }
        flashTask?.cancel()
        shakePhase = 0
        flashingPair = wrong
        if !motion.reduceMotion {
            withAnimation(MotionTokens.shake) { shakePhase = 1 }
        }
        flashTask = Task {
            try? await Task.sleep(for: .seconds(0.65))
            guard !Task.isCancelled else { return }
            flashingPair = nil
            shakePhase = 0
        }
    }

    private func isFlashing(_ id: Int, isLeft: Bool) -> Bool {
        guard let pair = flashingPair else { return false }
        return (isLeft ? pair.leftId : pair.rightId) == id
    }

    private func column(_ items: [TaskOption], isLeft: Bool, correct: [PairKey]) -> some View {
        VStack(spacing: Spacing.s) {
            ForEach(items) { item in
                ChoiceTileButton(text: item.text, state: state(item.id, isLeft: isLeft, correct: correct), minHeight: tileHeight) {
                    pick(item.id, isLeft: isLeft)
                }
                .onGeometryChange(for: CGFloat.self) { proxy in
                    proxy.size.height - Spacing.tileDepth
                } action: { face in
                    if face > tileHeight { tileHeight = face }
                }
                .modifier(ShakeEffect(animatableData: isFlashing(item.id, isLeft: isLeft) ? shakePhase : 0))
                .disabled(isMatched(item.id, isLeft: isLeft, correct: correct) || isOutOfTries(item.id, isLeft: isLeft, correct: correct) || attempt.isFinished)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func isMatched(_ id: Int, isLeft: Bool, correct: [PairKey]) -> Bool {
        if isLeft { return attempt.matchedLeftIDs.contains(id) }
        return correct.contains { $0.rightId == id && attempt.matchedLeftIDs.contains($0.leftId) }
    }

    /// Both sides of a pair that ran out of tries sit out, so its answer can't draw more misses.
    private func isOutOfTries(_ id: Int, isLeft: Bool, correct: [PairKey]) -> Bool {
        if isLeft { return attempt.exhaustedLeftIDs.contains(id) }
        return correct.contains { $0.rightId == id && attempt.exhaustedLeftIDs.contains($0.leftId) }
    }

    private func state(_ id: Int, isLeft: Bool, correct: [PairKey]) -> WordTileVisualState {
        if isMatched(id, isLeft: isLeft, correct: correct) { return .correct }
        if isFlashing(id, isLeft: isLeft) { return .incorrect }
        // Only the left item shows the miss: marking its right partner would name the answer on the board.
        if isLeft, attempt.exhaustedLeftIDs.contains(id) { return .incorrect }
        if attempt.isFinished { return .disabled }
        if (isLeft ? selectedLeftID : selectedRightID) == id { return .selected }
        return isOutOfTries(id, isLeft: isLeft, correct: correct) ? .disabled : .idle
    }

    private func pick(_ id: Int, isLeft: Bool) {
        if isLeft {
            selectedLeftID = selectedLeftID == id ? nil : id
        } else {
            selectedRightID = selectedRightID == id ? nil : id
        }
        guard let leftID = selectedLeftID, let rightID = selectedRightID else {
            store.answerPicked()
            return
        }
        store.submitPair(leftID: leftID, rightID: rightID)
        selectedLeftID = nil
        selectedRightID = nil
    }
}
