import SwiftUI

/// Sentence panel with one underlined blank and a bank of word tiles. Shared by the core Build stage
/// and Word Stack. Tapping a tile, or dropping it anywhere on the panel, flies it into the blank;
/// tapping it again (or dragging it off) sends it back. It never evaluates — the parent's Check does.
struct WordStackBoard: View {
    let prompt: String
    let options: [WordOption]
    @Binding var placedTileID: String?
    /// Set once the challenge is solved; locks the board.
    let correctTileID: String?
    let incorrectTileID: String?
    /// True while a wrong answer is shown; tiles wait for "Try again".
    var isLocked = false
    @Binding var isDragging: Bool
    let haptics: FeedbackProviding

    @Environment(\.motion) private var motion
    @Environment(\.scenePhase) private var scenePhase
    @State private var interaction = BuildInteractionState()

    private var completed: Bool { correctTileID != nil }

    var body: some View {
        VStack(spacing: Spacing.l) {
            sentencePanel
                .zIndex(0)

            ViewThatFits(in: .horizontal) {
                HStack(spacing: Spacing.s) { tiles }
                VStack(spacing: Spacing.s) { tiles }
            }
            .zIndex(1)
        }
        .coordinateSpace(.named(BuildInteractionState.boardSpace))
        .onGeometryChange(for: CGSize.self) { proxy in
            proxy.size
        } action: { _ in
            cancelInteraction()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { cancelInteraction() }
        }
        .onDisappear {
            interaction = BuildInteractionState()
            isDragging = false
        }
    }

    private var sentencePanel: some View {
        let parts = prompt.components(separatedBy: BuildChallenge.blank)
        let before = (parts.first ?? "").split(separator: " ").map(String.init)
        let after = parts.dropFirst().joined(separator: BuildChallenge.blank).split(separator: " ").map(String.init)
        let placedText = placedTileID.flatMap { id in options.first { $0.id == id }?.text }
        let spoken = prompt.replacingOccurrences(of: BuildChallenge.blank, with: placedText ?? String(localized: "blank"))
        let shape = RoundedRectangle(cornerRadius: Radii.card, style: .continuous)

        return FlowLayout(spacing: Spacing.xs, lineSpacing: Spacing.s) {
            ForEach(Array(before.enumerated()), id: \.offset) { _, word in
                sentenceWord(word)
            }
            DropSlot(
                isTargeted: interaction.isPanelTargeted,
                isFilled: placedTileID != nil,
                sentence: spoken,
                sizingText: options.map(\.text).max { $0.count < $1.count } ?? ""
            )
            .onGeometryChange(for: CGRect.self) { proxy in
                proxy.frame(in: .named(BuildInteractionState.boardSpace))
            } action: { frame in
                interaction.slotFrame = frame
            }
            ForEach(Array(after.enumerated()), id: \.offset) { _, word in
                sentenceWord(word)
            }
        }
        .padding(.horizontal, Spacing.m)
        .padding(.vertical, Spacing.xl)
        .frame(maxWidth: .infinity, minHeight: 175)
        .background(interaction.isPanelTargeted ? Color.selectedSurface : Color.clear, in: shape)
        .overlay(shape.strokeBorder(interaction.isPanelTargeted ? Color.interactive : .clear, lineWidth: 2))
        .animation(motion.animation(MotionTokens.lift), value: interaction.isPanelTargeted)
        .onGeometryChange(for: CGRect.self) { proxy in
            proxy.frame(in: .named(BuildInteractionState.boardSpace))
        } action: { frame in
            interaction.panelFrame = frame
        }
    }

    private func sentenceWord(_ word: String) -> some View {
        Text(verbatim: word)
            .font(Typography.sentence)
            .tracking(-0.4)
            .foregroundStyle(Color.ink)
            .fixedSize()
            .accessibilityHidden(true)
    }

    private var tiles: some View {
        ForEach(options) { option in
            let isPlaced = placedTileID == option.id
            DraggableWordTile(
                option: option,
                visualState: tileState(option),
                restingOffset: interaction.restingOffset(for: option.id, placedTileID: placedTileID),
                dropFrame: interaction.panelFrame,
                isPlaced: isPlaced,
                isInteractive: !completed && !isLocked,
                cancelToken: interaction.cancelToken,
                onFrameChange: { frame in
                    if interaction.tileFrames[option.id] != frame {
                        interaction.tileFrames[option.id] = frame
                    }
                },
                onTap: { toggle(option.id) },
                onDragBegan: { beginDrag(option.id) },
                onTargetChanged: { targeted in
                    interaction.isPanelTargeted = targeted
                    if targeted { haptics.selectionChanged() }
                },
                onDragEnded: { dropped in endDrag(option.id, dropped: dropped) },
                onDragCancelled: { resetDrag() }
            )
            // The bank keeps an empty well where a placed tile came from, so nothing reflows.
            .background(alignment: .top) {
                if isPlaced {
                    RoundedRectangle(cornerRadius: Radii.tile, style: .continuous)
                        .fill(Color.neutralSurface)
                        .padding(.bottom, Spacing.tileDepth)
                        .accessibilityHidden(true)
                }
            }
        }
    }

    private func tileState(_ option: WordOption) -> WordTileVisualState {
        if let correctTileID {
            return option.id == correctTileID ? .correct : .disabled
        }
        if placedTileID == option.id, incorrectTileID == option.id { return .incorrect }
        return .idle
    }

    private func toggle(_ tileID: String) {
        guard !completed, !isLocked else { return }
        if placedTileID == tileID {
            withAnimation(motion.travel(MotionTokens.returnToOrigin)) { placedTileID = nil }
        } else {
            withAnimation(motion.travel(MotionTokens.snap)) { placedTileID = tileID }
        }
        haptics.selectionChanged()
    }

    private func beginDrag(_ tileID: String) -> Bool {
        guard interaction.draggingTileID == nil else { return false }
        interaction.phase = .dragging(tileID: tileID)
        isDragging = true
        return true
    }

    /// Dropping on the panel places the tile; dropping elsewhere returns it to the bank. Neither submits.
    private func endDrag(_ tileID: String, dropped: Bool) -> Animation? {
        guard interaction.draggingTileID == tileID else { return motion.travel(MotionTokens.returnToOrigin) }
        interaction.isPanelTargeted = false
        interaction.phase = .idle
        isDragging = false

        if dropped {
            let animation = motion.travel(MotionTokens.snap)
            withAnimation(animation) { placedTileID = tileID }
            haptics.selectionChanged()
            return animation
        }
        let animation = motion.travel(MotionTokens.returnToOrigin)
        if placedTileID == tileID {
            withAnimation(animation) { placedTileID = nil }
        }
        return animation
    }

    private func resetDrag() {
        if interaction.draggingTileID != nil {
            interaction.phase = .idle
            isDragging = false
        }
        if interaction.isPanelTargeted {
            interaction.isPanelTargeted = false
        }
    }

    private func cancelInteraction() {
        guard interaction.draggingTileID != nil else { return }
        interaction.cancelToken += 1
        resetDrag()
    }
}
