import SwiftUI

/// The server's verdict on a committed run. Shown only after the commit answered: never a speculative win.
/// The celebration is short and never holds up "Next Level".
struct ChallengeResultsView: View {
    let outcome: ChallengeRunOutcome
    @Environment(ChallengeRunStore.self) private var run
    @Environment(ChallengeMapStore.self) private var map
    @Environment(PracticeSessionStore.self) private var practice
    @Environment(\.motion) private var motion
    @State private var celebrates = false
    @State private var showsConfetti = false
    @State private var hasAppeared = false

    private var result: ChallengeRunResult { outcome.result }
    private var celebrationEarned: Bool { outcome.isFirstClear || outcome.isNewBest }
    /// The next chapter is short of words: offer the Daily Lesson instead of a next level.
    private var nextChapterNeedsWords: ChallengeRunOutcome.WordsNeeded? { outcome.wordsNeeded }

    var body: some View {
        GeometryReader { viewport in
            ScrollView {
                VStack(spacing: 0) {
                    BrandBar()
                    Spacer(minLength: Spacing.xl)

                    if outcome.chapterCleared {
                        Image(systemName: "trophy.fill")
                            .font(.system(size: 52, weight: .bold))
                            .foregroundStyle(Color.reward)
                            .shadow(color: Color.rewardDepth, radius: 0, y: 3)
                            .padding(.bottom, Spacing.m)
                            .accessibilityHidden(true)
                    } else if motion.reduceMotion, celebrationEarned {
                        CelebrationBadge()
                            .padding(.bottom, Spacing.l)
                    }

                    Chip(text: chip, fill: outcome.isCleared ? .reward : .neutralSurface)

                    Text(headline)
                        .font(Typography.display)
                        .tracking(-1.4)
                        .foregroundStyle(Color.ink)
                        .multilineTextAlignment(.center)
                        .accessibilityAddTraits(.isHeader)
                        .padding(.top, Spacing.s)

                    stars
                        .padding(.top, Spacing.m)

                    if let note {
                        note
                            .font(Typography.secondary)
                            .foregroundStyle(Color.mutedInk)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.top, Spacing.m)
                    }

                    statGrid
                        .padding(.top, Spacing.l)
                }
                .padding(.horizontal, Spacing.screenGutter + 4)
                .padding(.top, Spacing.s)
                .padding(.bottom, Spacing.l)
                .frame(minHeight: viewport.size.height)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .safeAreaInset(edge: .bottom) {
            PinnedActionBar { actions }
        }
        .overlay {
            if celebrates {
                SyllieCelebrationView()
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
                    .transition(.opacity)
            }
        }
        .overlay {
            if showsConfetti {
                ConfettiBurst()
            }
        }
        .onAppear { hasAppeared = true }
        .task {
            guard celebrationEarned, !motion.reduceMotion else { return }
            celebrates = true
            try? await Task.sleep(for: SyllieCelebrationView.confettiCue)
            showsConfetti = true
            try? await Task.sleep(for: .seconds(MotionTokens.challengeCelebrationHold))
            motion.perform(MotionTokens.transition) {
                celebrates = false
                showsConfetti = false
            }
        }
    }

    // MARK: Copy

    private var chip: LocalizedStringKey {
        switch result.outcome {
        case .cleared:
            if outcome.chapterCleared { return "Chapter cleared" }
            if outcome.isNewBest { return "New best!" }
            return outcome.isFirstClear ? "Level cleared" : "Level complete"
        case .failed, .quit, .unknown:
            return "Not cleared"
        }
    }

    private var headline: LocalizedStringKey {
        switch result.outcome {
        case .cleared:
            if outcome.chapterCleared { return "Chapter \(outcome.node.chapterNo) done." }
            return outcome.isNewBest ? "New best." : "Nice run."
        case .failed, .quit, .unknown:
            return "Time’s up."
        }
    }

    private var note: Text? {
        if !outcome.isCleared {
            return Text("\(result.correctMatches) of \(goal) matched. Challenges are optional, and your Daily Lesson isn’t affected.")
        }
        if let preview = nextChapterNeedsWords {
            return Text("Learn \(preview.remaining) more words to unlock Chapter \(preview.chapterNo).")
        }
        if outcome.isNewBest {
            return Text("Best: \(outcome.previousBestStars) → \(result.bestStars) stars")
        }
        if !outcome.isFirstClear, result.starsThisRun < result.bestStars {
            return Text("Your best stays at \(result.bestStars) stars.")
        }
        if let next = outcome.nextNode, next.chapterNo == outcome.node.chapterNo {
            return Text("Level \(next.levelNo) is open.")
        }
        return nil
    }

    private var goal: Int {
        run.plan?.goalMatches ?? result.correctMatches
    }

    @ViewBuilder
    private var stars: some View {
        if outcome.chapterCleared, let chapter = map.chapter(outcome.node.chapterNo) {
            VStack(spacing: Spacing.xs) {
                StarRow(filled: result.starsThisRun, size: 34)
                Text("\(chapter.starsEarned) / \(chapter.maxStars) stars in this chapter")
                    .font(Typography.micro.weight(.semibold))
                    .foregroundStyle(Color.mutedInk)
            }
        } else {
            StarRow(filled: result.starsThisRun, size: 34)
        }
    }

    // MARK: Stats

    private struct Stat: Identifiable {
        let label: LocalizedStringKey
        let value: String
        var id: Int
    }

    private var stats: [Stat] {
        let locale = AppLanguage.active.locale
        var list: [(LocalizedStringKey, String)] = [
            ("Matched", "\(result.correctMatches)"),
            ("Mistakes", "\(result.mistakes)"),
        ]
        if outcome.isCleared {
            list.append(("Time (s)", ChallengeTimeFormat.elapsed(result.elapsedMs)))
        }
        list.append(("Longest combo", "\(result.longestCombo)"))
        list.append(("Score", result.score.formatted(.number.locale(locale))))
        list.append(("Best score", result.bestScore.formatted(.number.locale(locale))))
        return list.enumerated().map { Stat(label: $0.element.0, value: $0.element.1, id: $0.offset) }
    }

    private var statGrid: some View {
        let stats = stats
        return VStack(spacing: Spacing.s) {
            ForEach(Array(stride(from: 0, to: stats.count, by: 2)), id: \.self) { start in
                HStack(spacing: Spacing.s) {
                    ForEach(stats[start..<min(start + 2, stats.count)]) { stat in
                        statTile(stat)
                    }
                }
                .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func statTile(_ stat: Stat) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            Text(verbatim: stat.value)
                .font(Typography.screenTitle.monospacedDigit())
                .foregroundStyle(Color.ink)
            Text(stat.label)
                .font(Typography.micro)
                .foregroundStyle(Color.mutedInk)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding(Spacing.m)
        .cardSurface(radius: Radii.tile)
        .accessibilityElement(children: .combine)
        .opacity(hasAppeared ? 1 : 0)
        .offset(y: hasAppeared ? 0 : MotionTokens.enterOffset)
        .animation(
            motion.travel(MotionTokens.entrance.delay(MotionTokens.celebrationStatsDelay + Double(stat.id) * MotionTokens.celebrationStagger)),
            value: hasAppeared
        )
    }

    // MARK: Actions

    @ViewBuilder
    private var actions: some View {
        VStack(spacing: Spacing.s) {
            if !outcome.isCleared {
                PrimaryButton(title: "Try Again") { play(outcome.node) }
                SecondaryButton(title: "Map") { backToMap() }
            } else if let next = outcome.nextNode {
                PrimaryButton(title: "Next Level", shimmers: true) { play(next) }
                HStack(spacing: Spacing.s) {
                    SecondaryButton(title: "Replay level") { play(outcome.node) }
                    SecondaryButton(title: "Map") { backToMap() }
                }
            } else if nextChapterNeedsWords != nil {
                PrimaryButton(title: "Continue Daily") { continueDaily() }
                HStack(spacing: Spacing.s) {
                    SecondaryButton(title: "Replay level") { play(outcome.node) }
                    SecondaryButton(title: "Map") { backToMap() }
                }
            } else {
                PrimaryButton(title: "Replay level") { play(outcome.node) }
                SecondaryButton(title: "Map") { backToMap() }
            }
        }
    }

    private func play(_ node: ChallengeNodeRef) {
        Task { await run.play(node, level: map.level(node)) }
    }

    private func backToMap() {
        motion.perform(MotionTokens.transition) { run.close() }
    }

    private func continueDaily() {
        motion.perform(MotionTokens.transition) { run.close() }
        Task { await practice.start(.daily) }
    }
}

/// A Practice Lab round: counted locally, never sent. No stars, no score, no unlocks.
struct ChallengeSandboxResultsView: View {
    let summary: ChallengeSandboxSummary
    @Environment(ChallengeRunStore.self) private var run
    @Environment(\.motion) private var motion

    var body: some View {
        VStack(spacing: Spacing.m) {
            Spacer()
            Chip(text: "Practice round", fill: .neutralSurface)
            Text(headline)
                .font(Typography.display)
                .tracking(-1.4)
                .foregroundStyle(Color.ink)
                .multilineTextAlignment(.center)
                .accessibilityAddTraits(.isHeader)
            Text("\(summary.correctMatches) of \(summary.goal) matched · \(summary.mistakes) mistakes · longest combo \(summary.longestCombo)")
                .font(Typography.secondary)
                .foregroundStyle(Color.mutedInk)
                .multilineTextAlignment(.center)
            Text("Not scored. Nothing here is saved.")
                .font(Typography.micro)
                .foregroundStyle(Color.mutedInk)
            Spacer()
            PrimaryButton(title: "Play again") {
                guard let plan = run.plan else { return }
                run.startSandbox(plan: plan, timed: summary.isTimed)
            }
            SecondaryButton(title: "Done") {
                motion.perform(MotionTokens.transition) { run.close() }
            }
        }
        .padding(.horizontal, Spacing.screenGutter)
        .padding(.bottom, Spacing.m)
    }

    private var headline: LocalizedStringKey {
        summary.reachedGoal ? "All matched." : "Time’s up."
    }
}
