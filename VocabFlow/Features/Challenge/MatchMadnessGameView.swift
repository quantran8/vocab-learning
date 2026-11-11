import SwiftUI
import UIKit

/// Everything between tapping Play and returning to the map (or Home, or the Practice Lab).
struct MatchMadnessGameView: View {
    @Environment(ChallengeRunStore.self) private var store
    @Environment(PracticeSessionStore.self) private var practice
    @Environment(\.motion) private var motion
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        content
            // The run never pauses: back in the foreground, the clock is read again and may end the run.
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { store.tick() }
            }
    }

    @ViewBuilder
    private var content: some View {
        switch store.stage {
        case .idle:
            EmptyView()
        case .issuing:
            StatusScreen(title: "Getting your board ready", isBusy: true, showsFlyingSyllie: true)
        case .ready, .starting:
            ChallengeReadyView()
        case .playing:
            MatchMadnessBoardView()
        case .committing:
            StatusScreen(title: "Saving your result", isBusy: true, showsFlyingSyllie: true)
        case .results(let outcome):
            ChallengeResultsView(outcome: outcome)
        case .sandboxResults(let summary):
            ChallengeSandboxResultsView(summary: summary)
        case .commitFailed(let message):
            StatusScreen(
                title: "Your result isn’t saved yet",
                message: Text(verbatim: message) + Text(verbatim: "\n") + Text("If you leave, Syll saves it the next time you open the app.")
            ) {
                PrimaryButton(title: "Try saving again") {
                    Task { await store.retryCommit() }
                }
                SecondaryButton(title: "Back to map") { closeRun() }
            }
        case .runActive(let runID):
            StatusScreen(
                title: "Another challenge is still open",
                message: runID == nil
                    ? Text("Finish it where you started it, or try again in a few minutes.")
                    : Text("Leave it to start this one. It won’t count as a win.")
            ) {
                if runID != nil {
                    PrimaryButton(title: "Leave that run") {
                        Task { await store.leaveActiveRunAndRetry() }
                    }
                }
                SecondaryButton(title: "Back to map") { closeRun() }
            }
        case .failed(let failure):
            failureScreen(failure)
        }
    }

    @ViewBuilder
    private func failureScreen(_ failure: ChallengeRunStore.Failure) -> some View {
        switch failure {
        case .notEnoughVocabulary:
            StatusScreen(title: "Learn a few more words first", message: Text("This chapter opens once you’ve learned enough new words in your Daily Lesson.")) {
                PrimaryButton(title: "Continue Daily") { continueDaily() }
                SecondaryButton(title: "Back to map") { closeRun() }
            }
        case .contentUnavailable(let message):
            StatusScreen(title: "This challenge isn’t available right now", message: Text("Your stars are safe.") + Text(verbatim: " ") + Text(verbatim: message)) {
                PrimaryButton(title: "Keep Learning") { continueDaily() }
                SecondaryButton(title: "Back to map") { closeRun() }
            }
        case .expired:
            StatusScreen(title: "This run has ended", message: Text("Runs close after a while. Start a new one from the map.")) {
                SecondaryButton(title: "Back to map") { closeRun() }
            }
        case .invalidEvents(let message):
            StatusScreen(title: "We couldn’t check this run", message: Text(verbatim: message)) {
                SecondaryButton(title: "Back to map") { closeRun() }
            }
        case .levelLocked:
            StatusScreen(title: "This level isn’t open yet", message: Text("Clear the previous level to unlock.")) {
                SecondaryButton(title: "Back to map") { closeRun() }
            }
        case .issue(let message), .start(let message):
            StatusScreen(title: "Couldn’t start the challenge", message: Text(verbatim: message)) {
                SecondaryButton(title: "Back to map") { closeRun() }
            }
        }
    }

    private func closeRun() {
        motion.perform(MotionTokens.transition) { store.close() }
    }

    private func continueDaily() {
        motion.perform(MotionTokens.transition) { store.close() }
        Task { await practice.start(.daily) }
    }
}

// MARK: - Ready

/// The plan is frozen and the clock is stopped. Start asks the server to start the run; the clock begins only then.
private struct ChallengeReadyView: View {
    @Environment(ChallengeRunStore.self) private var store
    @Environment(\.motion) private var motion

    var body: some View {
        let plan = store.plan
        VStack(spacing: 0) {
            HStack {
                CloseRunButton { Task { await store.leave() } }
                Spacer()
            }

            Spacer(minLength: Spacing.l)

            VStack(spacing: Spacing.s) {
                if store.isSandbox {
                    Chip(text: "Practice round", fill: .neutralSurface)
                } else if let plan {
                    Text("Chapter \(plan.chapterNo) · Level \(plan.levelNo)")
                        .font(Typography.eyebrow)
                        .tracking(Typography.eyebrowTracking)
                        .textCase(.uppercase)
                        .foregroundStyle(Color.mutedInk)
                }
                Text("Match Madness")
                    .font(Typography.display)
                    .tracking(-1.2)
                    .foregroundStyle(Color.ink)
                    .multilineTextAlignment(.center)
                    .accessibilityAddTraits(.isHeader)
                if let plan {
                    VStack(spacing: Spacing.xxs) {
                        if store.isTimed {
                            Text("Match \(store.engineGoal) pairs in \(plan.timeLimitMs / 1000) seconds")
                        } else {
                            Text("Match \(store.engineGoal) pairs. No timer.")
                        }
                        Text("\(plan.visiblePairs) pairs visible at once")
                    }
                    .font(Typography.secondary)
                    .foregroundStyle(Color.mutedInk)
                    .multilineTextAlignment(.center)
                }
            }

            if let plan, store.isTimed, !store.isSandbox {
                StarRules(criteria: plan.starCriteria, timeLimitMs: plan.timeLimitMs)
                    .padding(.top, Spacing.l)
            }

            if !store.hasSeenTutorial {
                TutorialHint()
                    .padding(.top, Spacing.xl)
            }

            if store.isSandbox {
                Text("Nothing here is scored or saved.")
                    .font(Typography.micro)
                    .foregroundStyle(Color.mutedInk)
                    .padding(.top, Spacing.l)
            }

            Spacer(minLength: Spacing.l)

            if let error = store.startError {
                Text(verbatim: error)
                    .font(Typography.secondary)
                    .foregroundStyle(Color.errorInk)
                    .multilineTextAlignment(.center)
                    .padding(.bottom, Spacing.s)
            }
            PrimaryButton(title: "Start", isEnabled: store.stage == .ready, shimmers: true) {
                Task { await store.begin() }
            }
        }
        .padding(.horizontal, Spacing.screenGutter)
        .padding(.bottom, Spacing.m)
        .overlay {
            if store.stage == .starting {
                ProgressView().controlSize(.large)
            }
        }
    }
}

/// The level's star rules, from the plan. One star is any clear; two and three need both bounds.
/// Shown before the first ever game: one line, two example tiles. No tutorial series.
private struct TutorialHint: View {
    var body: some View {
        VStack(spacing: Spacing.s) {
            HStack(spacing: Spacing.s) {
                exampleTile("allocate", selected: true)
                Image(systemName: "arrow.left.and.right")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(Color.mutedInk)
                exampleTile("phân bổ", selected: true)
            }
            .accessibilityHidden(true)
            Text("Tap a word, then its meaning, in either order. Wrong pairs only reset your combo.")
                .font(Typography.secondary)
                .foregroundStyle(Color.ink)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(Spacing.m)
        .cardSurface(radius: Radii.tile, fill: .quietSurface)
    }

    private func exampleTile(_ text: String, selected: Bool) -> some View {
        Text(verbatim: text)
            .font(Typography.tile)
            .foregroundStyle(Color.selectedInk)
            .padding(.horizontal, Spacing.s)
            .padding(.vertical, Spacing.xs)
            .background(Color.selectedSurface, in: RoundedRectangle(cornerRadius: Radii.chip, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Radii.chip, style: .continuous).strokeBorder(Color.interactive, lineWidth: 2))
    }
}

struct CloseRunButton: View {
    var label: LocalizedStringKey = "Exit challenge"
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "xmark")
                .font(.system(size: 20, weight: .semibold))
                .frame(width: Spacing.minTouchTarget, height: Spacing.minTouchTarget)
        }
        .foregroundStyle(Color.mutedInk)
        .padding(.leading, -Spacing.s)
        .accessibilityLabel(Text(label))
    }
}

// MARK: - Board

private struct MatchMadnessBoardView: View {
    /// Spoken once each as the clock passes them.
    private static let announcedSeconds: Set<Int> = [60, 30, 10]

    @Environment(ChallengeRunStore.self) private var store
    @Environment(\.motion) private var motion
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOver
    @State private var confirmsExit = false
    @State private var wordSlots: [String?] = []
    @State private var meaningSlots: [String?] = []
    /// Just-matched tiles still showing as correct before they fade out.
    @State private var correctTiles: Set<String> = []
    @State private var lastOnBoard: Set<String> = []
    /// Tallest tile face seen so far; every tile uses it so both columns line up, as in `MatchTaskView`.
    @State private var tileHeight: CGFloat = Spacing.matchTileMinHeight

    var body: some View {
        let game = store.game
        let goal = store.engineGoal
        let matched = game?.correctCount ?? 0

        VStack(spacing: Spacing.s) {
            header(matched: matched, goal: goal)

            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text("Match the pairs")
                    .font(Typography.screenTitle)
                    .foregroundStyle(Color.ink)
                    .accessibilityAddTraits(.isHeader)
                stats(game)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, Spacing.xs)

            // The gutter sits inside the scroll view so a lifted (scaled) tile isn't clipped at the edge.
            ScrollView {
                board(game)
                    .padding(.vertical, Spacing.xs)
                    .padding(.horizontal, Spacing.screenGutter)
            }
            .scrollBounceBehavior(.basedOnSize)
            .padding(.horizontal, -Spacing.screenGutter)
        }
        .padding(.horizontal, Spacing.screenGutter)
        .padding(.bottom, Spacing.s)
        .alert(exitTitle, isPresented: $confirmsExit) {
            Button("Keep playing", role: .cancel) {}
            Button("Exit", role: .destructive) {
                Task { await store.quit() }
            }
        } message: {
            Text(exitMessage)
        }
        .onChange(of: store.feedback.count) { _, _ in react(to: store.feedback.value) }
        .onAppear { syncSlots() }
        .onChange(of: store.game?.wordOrder) { _, _ in syncSlots() }
        .onChange(of: store.game?.meaningOrder) { _, _ in syncSlots() }
        .onChange(of: store.remainingMs / 1000) { old, new in
            guard voiceOver, store.isTimed, new < old, Self.announcedSeconds.contains(new) else { return }
            announce(String(localized: "\(new) seconds left", bundle: .appLanguage))
        }
    }

    private var exitTitle: LocalizedStringKey {
        store.isSandbox ? "Leave practice?" : "Exit challenge?"
    }

    private var exitMessage: LocalizedStringKey {
        store.isSandbox ? "This practice round isn’t saved." : "This run won’t be saved as a win."
    }

    private func header(matched: Int, goal: Int) -> some View {
        HStack(spacing: Spacing.s) {
            CloseRunButton(label: store.isSandbox ? "Leave practice" : "Exit challenge") { confirmsExit = true }

            ProgressTrack(fraction: goal > 0 ? CGFloat(matched) / CGFloat(goal) : 0)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text("Matched"))
                .accessibilityValue(Text("\(matched) of \(goal)"))

            timer
        }
    }

    @ViewBuilder
    private var timer: some View {
        if store.isTimed {
            let remaining = store.remainingMs
            let urgent = remaining <= 10_000
            Text(verbatim: ChallengeTimeFormat.countdown(remaining))
                .font(Typography.emphasis.monospacedDigit())
                .foregroundStyle(urgent ? Color.errorInk : Color.ink)
                .padding(.horizontal, Spacing.s)
                .padding(.vertical, Spacing.xxs + 2)
                .background(urgent ? Color.errorSurface : Color.neutralSurface, in: Capsule())
                .frame(minWidth: Spacing.minTouchTarget, minHeight: Spacing.minTouchTarget)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text("Time left"))
                .accessibilityValue(Text("\(Int((Double(remaining) / 1000).rounded(.up))) seconds"))
        } else {
            Text("Untimed")
                .font(Typography.micro.weight(.bold))
                .foregroundStyle(Color.mutedInk)
                .padding(.horizontal, Spacing.s)
                .padding(.vertical, Spacing.xxs + 2)
                .background(Color.neutralSurface, in: Capsule())
        }
    }

    private func board(_ game: MatchMadnessState?) -> some View {
        HStack(alignment: .top, spacing: Spacing.s) {
            column(
                slots: displayed(wordSlots, order: game?.wordOrder),
                side: .word,
                selected: game?.selectedWordTileID
            )
            column(
                slots: displayed(meaningSlots, order: game?.meaningOrder),
                side: .meaning,
                selected: game?.selectedMeaningTileID
            )
        }
    }

    private func displayed(_ slots: [String?], order: [String]?) -> [String?] {
        slots.isEmpty ? (order ?? []).map(Optional.some) : slots
    }

    private func syncSlots() {
        guard let game = store.game else { return }
        let onBoard = Set(game.wordOrder + game.meaningOrder)
        defer { lastOnBoard = onBoard }
        if lastOnBoard.isDisjoint(with: onBoard) {
            correctTiles = []
        } else {
            let matched = lastOnBoard.subtracting(onBoard)
            if !matched.isEmpty {
                correctTiles.formUnion(matched)
                Task {
                    try? await Task.sleep(for: .seconds(MotionTokens.matchCorrectHold))
                    correctTiles.subtract(matched)
                    syncSlots()
                }
            }
        }
        wordSlots = ChallengeBoardSlots.reconcile(wordSlots, with: game.wordOrder, holding: correctTiles)
        meaningSlots = ChallengeBoardSlots.reconcile(meaningSlots, with: game.meaningOrder, holding: correctTiles)
    }

    private var tileFade: AnyTransition {
        .asymmetric(
            insertion: .opacity.animation(motion.animation(MotionTokens.matchFadeIn)),
            removal: .opacity.animation(motion.animation(MotionTokens.matchFadeOut))
        )
    }

    private func column(slots: [String?], side: MatchMadnessTile.Side, selected: String?) -> some View {
        VStack(spacing: Spacing.s) {
            ForEach(Array(slots.enumerated()), id: \.offset) { _, tileID in
                ZStack {
                    if let tileID {
                        MatchMadnessTile(
                            text: text(for: tileID, side: side),
                            side: side,
                            isSelected: selected == tileID,
                            isWrong: store.wrongTileIDs.contains(tileID),
                            isCorrect: correctTiles.contains(tileID),
                            minHeight: tileHeight,
                            shakes: store.shakeCounts[tileID] ?? 0
                        ) {
                            switch side {
                            case .word: store.tapWord(tileID)
                            case .meaning: store.tapMeaning(tileID)
                            }
                        }
                        .onGeometryChange(for: CGFloat.self) { proxy in
                            proxy.size.height - Spacing.tileDepth
                        } action: { face in
                            if face > tileHeight { tileHeight = face }
                        }
                        .id(tileID)
                        .transition(tileFade)
                    }
                }
                .frame(maxWidth: .infinity, minHeight: tileHeight + Spacing.tileDepth)
            }
        }
        .frame(maxWidth: .infinity)
        // A taller or shorter meaning resizes its slot smoothly instead of snapping.
        .animation(motion.animation(MotionTokens.matchFadeOut), value: slots)
    }

    private func text(for tileID: String, side: MatchMadnessTile.Side) -> String {
        switch side {
        case .word: store.pair(forWordTile: tileID)?.word ?? ""
        case .meaning: store.pair(forMeaningTile: tileID)?.meaning ?? ""
        }
    }

    private func stats(_ game: MatchMadnessState?) -> some View {
        let combo = game?.combo ?? 0
        return HStack(alignment: .firstTextBaseline, spacing: Spacing.s) {
            Text("Combo ×\(combo)")
                .font(Typography.secondary.weight(.bold).monospacedDigit())
                .foregroundStyle(combo > 1 ? Color.selectedInk : Color.mutedInk)
                .contentTransition(.numericText(value: Double(combo)))
                .animation(motion.animation(MotionTokens.snap), value: combo)
            if let score = game?.provisionalScore.map({ max($0, 0) }) {
                Text("Score \(score)")
                    .font(Typography.secondary.monospacedDigit())
                    .foregroundStyle(Color.mutedInk)
                    .contentTransition(.numericText(value: Double(score)))
                    .animation(motion.animation(MotionTokens.snap), value: score)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func react(to feedback: MatchMadnessFeedback) {
        switch feedback {
        case .correct:
            if voiceOver { announce(String(localized: "Match", bundle: .appLanguage)) }
        case .wrong:
            if voiceOver { announce(String(localized: "Not a match", bundle: .appLanguage)) }
        case .goalReached:
            if voiceOver { announce(String(localized: "All pairs matched", bundle: .appLanguage)) }
        case .none, .selected, .deselected:
            break
        }
    }

    private func announce(_ text: String) {
        UIAccessibility.post(notification: .announcement, argument: text)
    }
}
