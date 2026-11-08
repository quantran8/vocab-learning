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
                Text(verbatim: "syll")
                    .font(Typography.wordmark)
                    .tracking(-0.6)
                    .foregroundStyle(Color.ink)
                    .accessibilityLabel(Text(verbatim: "Syll"))

                PunctuatedTitle(text: "Daily Lesson")
                    .padding(.top, Spacing.xl)

                dailyLesson(due: due)
                    .padding(.top, Spacing.l)

                sectionTitle("Checkpoint Challenge")
                    .padding(.top, Spacing.xl + Spacing.l)

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

    /// The screen's one main action. It keeps the lesson's thick edge as an invitation into the lesson.
    private func dailyLesson(due: Int) -> some View {
        VStack(alignment: .leading, spacing: Spacing.l) {
            HStack(alignment: .bottom, spacing: Spacing.m) {
                VStack(alignment: .leading, spacing: Spacing.m) {
                    Text("Today’s session")
                        .font(Typography.emphasis)
                        .foregroundStyle(Color.ink)
                    StatRow(label: "Words to review", value: due)
                    StatRow(label: "New words / day", value: plan.current.wordsPerDay)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                LessonMascot()
            }
            PrimaryButton(title: due > 0 ? "Start" : "Start Flow", shimmers: true) { start(.daily) }
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
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            Text(label)
                .font(Typography.secondary)
                .foregroundStyle(Color.mutedInk)
                .fixedSize(horizontal: false, vertical: true)
            Text(verbatim: "\(value)")
                .font(Typography.screenTitle.monospacedDigit())
                .foregroundStyle(Color.ink)
                .contentTransition(.numericText(value: Double(value)))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Mascot

/// Syllie beside the lesson stats, standing on a soft shadow (the `HomeSyllie` artboard). One cycle: he idles for
/// `idleBeat`, plays one random scene (a letter to bounce or a paper plane to chase), then dozes off (snoring).
/// A tap wakes him and the cycle starts again. With reduced motion he skips the play and just dozes off.
/// Decorative except for that tap.
private struct LessonMascot: View {
    /// How long Syllie idles before he plays.
    private static let idleBeat: Duration = .seconds(4)

    @Environment(\.motion) private var motion
    @State private var scene = HomeSyllieScene.idle

    var body: some View {
        ZStack(alignment: .bottom) {
            Ellipse()
                .fill(Color.neutralSurface)
                .frame(width: 96, height: 12)
                .accessibilityHidden(true)
            // Accessibility comes from HomeSyllieView: hidden while awake, a "wake him up" button while asleep.
            HomeSyllieView(scene: scene) { scene = .idle }
            .frame(width: 124, height: 134)
            .padding(.bottom, Spacing.xs)
        }
        .task(id: scene) {
            switch scene {
            case .idle:
                guard await pause(Self.idleBeat) else { return }
                scene = motion.reduceMotion ? .sleepy : (HomeSyllieScene.plays.randomElement() ?? .playLetters)
            case .playLetters, .planeChase:
                guard let duration = scene.duration, await pause(duration) else { return }
                scene = .sleepy
            case .sleepy, .wakeUp:
                return
            }
        }
    }

    /// Sleeps for `duration`; false if the task was cancelled (the scene changed or the view went away).
    private func pause(_ duration: Duration) async -> Bool {
        do {
            try await Task.sleep(for: duration)
            return true
        } catch {
            return false
        }
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
                SecondaryButton(title: "Start challenge", action: onStart)
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
