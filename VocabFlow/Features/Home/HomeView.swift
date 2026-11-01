import SwiftUI

struct HomeView: View {
    @Environment(PracticeSessionStore.self) private var practice
    @Environment(LearnerStore.self) private var learner
    @Environment(LearningPlanStore.self) private var plan
    @Environment(\.motion) private var motion

    var body: some View {
        let due = learner.home?.dueCount ?? 0

        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text(verbatim: "vocab flow")
                    .font(Typography.wordmark)
                    .tracking(-0.6)
                    .foregroundStyle(Color.ink)
                    .accessibilityLabel(Text(verbatim: "Vocab Flow"))

                sectionTitle("Daily Lesson")
                    .padding(.top, Spacing.xl)

                sessionCard(due: due)
                    .padding(.top, Spacing.m)

                sectionTitle("Checkpoint Challenge")
                    .padding(.top, Spacing.xl)

                CheckpointChallengeCard(home: learner.home, challenge: learner.challenges.first) {
                    start(.checkpointChallenge, challengeID: learner.challenges.first?.id)
                }
                .padding(.top, Spacing.m)
            }
            .padding(.horizontal, Spacing.screenGutter)
            .padding(.top, Spacing.m)
            .padding(.bottom, Spacing.l)
        }
        .refreshable { await learner.refresh() }
    }

    private func sectionTitle(_ title: LocalizedStringKey) -> some View {
        Text(title)
            .font(Typography.screenTitle)
            .tracking(Typography.tightTracking)
            .foregroundStyle(Color.ink)
            .accessibilityAddTraits(.isHeader)
    }

    private func sessionCard(due: Int) -> some View {
        VStack(alignment: .leading, spacing: Spacing.l) {
            VStack(spacing: Spacing.m) {
                StatRow(label: "Words to review", value: due)
                StatRow(label: "New words / day", value: plan.current.wordsPerDay)
            }
            PrimaryButton(title: due > 0 ? "Continue flow" : "Start Flow") { start(.daily) }
        }
        .padding(Spacing.m + 2)
        .cardSurface()
    }

    private func start(_ mode: SessionMode, challengeID: String? = nil) {
        Task { await practice.start(mode, challengeID: challengeID) }
    }
}

// MARK: - Stat row

private struct StatRow: View {
    let label: LocalizedStringKey
    let value: Int

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Spacing.s) {
            Text(label)
                .font(Typography.body)
                .foregroundStyle(Color.mutedInk)
            Spacer(minLength: 0)
            Text(verbatim: "\(value)")
                .font(Typography.tile.monospacedDigit())
                .foregroundStyle(Color.ink)
                .contentTransition(.numericText(value: Double(value)))
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Checkpoint challenge

private struct CheckpointChallengeCard: View {
    let home: LearnHome?
    /// Nil if the challenge list has not loaded; starting without an ID takes the oldest open one.
    let challenge: CheckpointChallenge?
    let onStart: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            HStack(alignment: .firstTextBaseline, spacing: Spacing.s) {
                Text("Your recent words")
                    .font(Typography.emphasis)
                    .foregroundStyle(Color.ink)
                Spacer(minLength: 0)
                if let home, home.checkpointAvailable == 0 {
                    Text(verbatim: "\(home.checkpointSessionsDone) / \(home.checkpointSessionsRequired)")
                        .font(Typography.tile.monospacedDigit())
                        .foregroundStyle(Color.ink)
                        .accessibilityHidden(true)
                }
            }

            if let home, home.checkpointAvailable > 0 {
                if let challenge {
                    Text("^[\(challenge.meaningCount) word](inflect: true) to recall")
                        .font(Typography.secondary)
                        .foregroundStyle(Color.mutedInk)
                }
                PrimaryButton(title: "Start challenge", action: onStart)
            } else {
                if let home {
                    sessionProgress(home)
                }
                Text(lockedHint)
                    .font(Typography.secondary)
                    .foregroundStyle(Color.mutedInk)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(Spacing.m + 2)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardSurface()
    }

    private var lockedHint: LocalizedStringKey {
        guard let home, home.checkpointSessionsDone < home.checkpointSessionsRequired else {
            return "Keep learning new words to open your next challenge."
        }
        let remaining = home.checkpointSessionsRequired - home.checkpointSessionsDone
        return "\(remaining) more sessions to unlock your next challenge."
    }

    private func sessionProgress(_ home: LearnHome) -> some View {
        ProgressTrack(fraction: home.checkpointProgress)
            .accessibilityElement()
            .accessibilityLabel(Text("Progress to your next challenge"))
            .accessibilityValue(Text("\(home.checkpointSessionsDone) of \(home.checkpointSessionsRequired) sessions"))
    }
}
