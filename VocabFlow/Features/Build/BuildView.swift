import SwiftUI

struct BuildView: View {
    let index: Int
    @Environment(SessionStore.self) private var store
    @Environment(\.motion) private var motion
    @Environment(\.scenePhase) private var scenePhase
    @State private var interaction = BuildInteractionState()

    var body: some View {
        if let challenge = store.buildChallenge(at: index) {
            screen(challenge)
        }
    }

    private func screen(_ challenge: BuildChallenge) -> some View {
        let completed = store.isBuildCompleted(index: index)
        let total = store.content.buildChallenges.count

        return FlowScaffold(
            stage: "Build",
            stageCurrent: index + 1,
            stageTotal: total,
            isScrollDisabled: interaction.draggingTileID != nil
        ) {
            VStack(spacing: Spacing.l) {
                StageIntro(
                    number: 2,
                    label: "Build the sentence",
                    title: challenge.context,
                    subtitle: "Pick the word that fits naturally.",
                    systemImage: "square.stack.3d.up.fill"
                )

                board(challenge, completed: completed)

                feedback(challenge)
                    .frame(minHeight: 88, alignment: .top)
                    .animation(motion.animation(MotionTokens.feedback), value: store.state.feedback)
            }
        } action: {
            action(challenge, completed: completed, isLast: index + 1 >= total)
        }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { cancelInteraction() }
        }
        .onDisappear { interaction = BuildInteractionState() }
    }

    private func board(_ challenge: BuildChallenge, completed: Bool) -> some View {
        VStack(spacing: Spacing.l) {
            sentenceBoard(challenge, completed: completed)
                .zIndex(0)

            Eyebrow(text: completed ? "Nicely placed" : "Tap or drag a tile")

            ViewThatFits(in: .horizontal) {
                HStack(spacing: Spacing.s) { tiles(challenge, completed: completed) }
                VStack(spacing: Spacing.s) { tiles(challenge, completed: completed) }
            }
            .zIndex(1)
        }
        .coordinateSpace(.named(BuildInteractionState.boardSpace))
        .onGeometryChange(for: CGSize.self) { proxy in
            proxy.size
        } action: { _ in
            cancelInteraction()
        }
    }

    private func sentenceBoard(_ challenge: BuildChallenge, completed: Bool) -> some View {
        let parts = challenge.prompt.components(separatedBy: BuildChallenge.blank)
        let before = (parts.first ?? "").split(separator: " ").map(String.init)
        let after = parts.dropFirst().joined(separator: BuildChallenge.blank).split(separator: " ").map(String.init)
        let spoken = challenge.prompt.replacingOccurrences(
            of: BuildChallenge.blank,
            with: completed ? (correctOption(challenge)?.text ?? "") : String(localized: "blank")
        )

        return FlowLayout(spacing: Spacing.xs, lineSpacing: Spacing.s) {
            ForEach(Array(before.enumerated()), id: \.offset) { _, word in
                sentenceWord(word)
            }
            DropSlot(
                isTargeted: interaction.isSlotTargeted,
                isFilled: completed,
                sentence: spoken,
                sizingText: challenge.options.map(\.text).max { $0.count < $1.count } ?? ""
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
        .background {
            ZStack {
                Color.surface
                DotGrid()
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: Radii.card, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Radii.card, style: .continuous).strokeBorder(Color.stroke))
    }

    private func sentenceWord(_ word: String) -> some View {
        Text(verbatim: word)
            .font(Typography.sentence)
            .tracking(-0.4)
            .foregroundStyle(Color.ink)
            .fixedSize()
            .accessibilityHidden(true)
    }

    private func tiles(_ challenge: BuildChallenge, completed: Bool) -> some View {
        ForEach(challenge.options) { option in
            DraggableWordTile(
                option: option,
                visualState: tileState(option, challenge: challenge, completed: completed),
                restingOffset: interaction.restingOffset(for: option.id),
                slotFrame: interaction.slotFrame,
                isInteractive: !completed,
                cancelToken: interaction.cancelToken,
                onFrameChange: { frame in
                    if interaction.tileFrames[option.id] != frame {
                        interaction.tileFrames[option.id] = frame
                    }
                },
                onTap: { toggleSelection(option.id, completed: completed) },
                onDragBegan: { beginDrag(option.id) },
                onTargetChanged: { targeted in
                    interaction.isSlotTargeted = targeted
                    if targeted { store.haptics.selectionChanged() }
                },
                onDragEnded: { dropped in endDrag(option.id, dropped: dropped, challenge: challenge) },
                onDragCancelled: { resetDrag() }
            )
        }
    }

    @ViewBuilder
    private func feedback(_ challenge: BuildChallenge) -> some View {
        switch store.state.feedback {
        case .buildCorrect(let tileID):
            let text = challenge.option(id: tileID)?.text ?? ""
            FeedbackBanner(
                kind: .success,
                title: String(localized: "Nicely done!"),
                message: String(localized: "“\(challenge.filledPrompt(with: text))” — “\(text)” fits this context.")
            )
            .transition(motion.popTransition)
        case .buildIncorrect(let tileID):
            let text = challenge.option(id: tileID)?.text ?? ""
            FeedbackBanner(
                kind: .error,
                title: String(localized: "Not quite — try another word"),
                message: challenge.explanations[tileID] ?? String(localized: "“\(text)” doesn’t fit this sentence.")
            )
            .transition(motion.popTransition)
        default:
            EmptyView()
        }
    }

    @ViewBuilder
    private func action(_ challenge: BuildChallenge, completed: Bool, isLast: Bool) -> some View {
        if completed {
            PrimaryButton(title: isLast ? "Continue to recall" : "Continue") {
                motion.perform(MotionTokens.transition) { store.next() }
            }
        } else {
            let selected = interaction.selectedTileID
            let alreadyChecked = selected.map { store.state.feedback == .buildIncorrect(tileID: $0) } ?? false
            PrimaryButton(
                title: "Check answer",
                requirement: alreadyChecked ? "That word was already checked — pick another." : "Select a word or drag it into the slot.",
                isEnabled: selected != nil && !alreadyChecked
            ) {
                if let selected { commit(selected, challenge: challenge) }
            }
        }
    }

    private func correctOption(_ challenge: BuildChallenge) -> WordOption? {
        challenge.acceptedOptionIDs.first.flatMap(challenge.option(id:))
    }

    private func tileState(_ option: WordOption, challenge: BuildChallenge, completed: Bool) -> WordTileVisualState {
        if completed {
            return challenge.acceptedOptionIDs.contains(option.id) ? .correct : .disabled
        }
        if interaction.selectedTileID == option.id { return .selected }
        if store.state.feedback == .buildIncorrect(tileID: option.id) { return .incorrect }
        return .idle
    }

    private func toggleSelection(_ tileID: String, completed: Bool) {
        guard !completed else { return }
        interaction.selectedTileID = interaction.selectedTileID == tileID ? nil : tileID
        store.haptics.selectionChanged()
    }

    private func beginDrag(_ tileID: String) -> Bool {
        guard interaction.draggingTileID == nil else { return false }
        interaction.phase = .dragging(tileID: tileID)
        interaction.selectedTileID = nil
        return true
    }

    private func endDrag(_ tileID: String, dropped: Bool, challenge: BuildChallenge) -> Animation? {
        guard interaction.draggingTileID == tileID else { return motion.travel(MotionTokens.returnToOrigin) }
        interaction.isSlotTargeted = false
        interaction.phase = .idle
        guard dropped else { return motion.travel(MotionTokens.returnToOrigin) }
        return commit(tileID, challenge: challenge)
    }

    @discardableResult
    private func commit(_ tileID: String, challenge: BuildChallenge) -> Animation? {
        interaction.phase = .evaluating
        store.submitBuild(tileID: tileID)
        interaction.selectedTileID = nil
        let isCorrect = store.isBuildCompleted(index: index) && challenge.acceptedOptionIDs.contains(tileID)
        interaction.phase = .showingFeedback(isCorrect: isCorrect)
        guard isCorrect else { return motion.travel(MotionTokens.returnToOrigin) }
        let animation = motion.travel(MotionTokens.snap)
        withAnimation(animation) {
            interaction.placedTileID = tileID
        }
        return animation
    }

    private func resetDrag() {
        if interaction.draggingTileID != nil {
            interaction.phase = .idle
        }
        if interaction.isSlotTargeted {
            interaction.isSlotTargeted = false
        }
    }

    private func cancelInteraction() {
        guard interaction.draggingTileID != nil else { return }
        interaction.cancelToken += 1
        resetDrag()
    }
}
