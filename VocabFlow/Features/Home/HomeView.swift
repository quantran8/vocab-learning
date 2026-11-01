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

                Text("DAILY SESSION")
                    .font(Typography.eyebrow)
                    .tracking(Typography.eyebrowTracking)
                    .foregroundStyle(Color.mutedInk)
                    .padding(.top, Spacing.xl)

                Text(heading(due: due))
                    .font(Typography.display)
                    .tracking(-1.2)
                    .foregroundStyle(Color.ink)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
                    .padding(.top, Spacing.xs)

                sessionCard(due: due)
                    .padding(.top, Spacing.m + 2)

                Rectangle()
                    .fill(Color.stroke)
                    .frame(height: 1)
                    .padding(.vertical, Spacing.l + 4)
                    .accessibilityHidden(true)

                Text("Checkpoint Challenge")
                    .font(Typography.screenTitle)
                    .tracking(Typography.tightTracking)
                    .foregroundStyle(Color.ink)
                    .accessibilityAddTraits(.isHeader)

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

    private func heading(due: Int) -> LocalizedStringKey {
        let weekday = Calendar.current.component(.weekday, from: .now)
        if !plan.current.learningDays.contains(weekday) { return "Take it easy" }
        return due > 0 ? "Time to revisit" : "Ready to learn?"
    }

    private func sessionCard(due: Int) -> some View {
        VStack(alignment: .leading, spacing: Spacing.l) {
            HStack(spacing: Spacing.xs) {
                StatChip(value: due, label: "to review")
                StatChip(value: plan.current.wordsPerDay, label: "new words / day")
            }
            PrimaryButton(title: due > 0 ? "Continue flow" : "Start Flow") { start(.daily) }
        }
        .padding(Spacing.l - 4)
        .cardSurface()
        .shadow(color: Color.ink.opacity(0.06), radius: 6, y: 4)
    }

    private func start(_ mode: SessionMode, challengeID: String? = nil) {
        Task { await practice.start(mode, challengeID: challengeID) }
    }
}

// MARK: - Stat chip

private struct StatChip: View {
    let value: Int
    let label: LocalizedStringKey

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Spacing.xs) {
            Text(verbatim: "\(value)")
                .font(Typography.screenTitle.monospacedDigit())
                .contentTransition(.numericText(value: Double(value)))
            Text(label)
                .font(Typography.micro.weight(.semibold))
        }
        .foregroundStyle(Color.ink)
        .padding(.horizontal, Spacing.s)
        .padding(.vertical, Spacing.xs + 2)
        .background(Color.neutralSurface, in: RoundedRectangle(cornerRadius: Radii.chip, style: .continuous))
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
            Text("Your recent words")
                .font(Typography.emphasis)
                .foregroundStyle(Color.ink)

            if let home, home.checkpointAvailable > 0 {
                if let challenge {
                    Text("^[\(challenge.meaningCount) word](inflect: true) to recall")
                        .font(Typography.micro)
                        .foregroundStyle(Color.mutedInk)
                }
                PrimaryButton(title: "Start challenge", action: onStart)
            } else {
                if let home {
                    sessionProgress(home)
                }
                Text("Keep learning new words to open your next challenge.")
                    .font(Typography.micro)
                    .foregroundStyle(Color.mutedInk)
            }
        }
        .padding(Spacing.m + 2)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardSurface()
    }

    private func sessionProgress(_ home: LearnHome) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            ProgressTrack(fraction: home.checkpointProgress)
            Text("\(home.checkpointSessionsDone) of \(home.checkpointSessionsRequired) sessions")
                .font(Typography.micro.weight(.semibold).monospacedDigit())
                .foregroundStyle(Color.ink)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("Progress to your next challenge"))
    }
}
