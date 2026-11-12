import SwiftUI

struct HomeView: View {
    @Environment(PracticeSessionStore.self) private var practice
    @Environment(LearnerStore.self) private var learner
    @Environment(LearningPlanStore.self) private var plan
    @Environment(ChallengeMapStore.self) private var challengeMap
    @Environment(\.motion) private var motion
    /// Pushes the Challenge Map onto Home's navigation stack.
    var onOpenChallengeMap: () -> Void = {}
    /// Opens the Focus sheet (topics and collection).
    var onChooseTopics: () -> Void = {}
    var onOpenRandomPractice: () -> Void = {}
    @State private var isChoosingReviewLoad = false
    @State private var isShowingLessonInfo = false

    var body: some View {
        let due = learner.home?.dueCount ?? 0

        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // Text(verbatim: "syll")
                //     .font(Typography.wordmark)
                //     .tracking(-0.6)
                //     .foregroundStyle(Color.ink)
                //     .accessibilityLabel(Text(verbatim: "Syll"))

                PunctuatedTitle(text: "Daily Lesson")
                    .padding(.top, Spacing.xl)

                dailyLesson(due: due)
                    .padding(.top, Spacing.l)

                sectionTitle("Challenge")
                    .padding(.top, Spacing.xl + Spacing.l)

                if isOutOfNewWords {
                    Text(plan.current.hasAllTopics
                         ? "Choose a new collection to keep your journey going."
                         : "Choose new topics to keep your journey going.")
                        .font(Typography.secondary)
                        .foregroundStyle(Color.mutedInk)
                        .padding(.top, Spacing.xs)
                }

                // Out of new words, "keep learning" means picking topics: Daily has nothing new to give.
                ChallengeHomeCard(
                    onOpenMap: onOpenChallengeMap,
                    onStartDaily: { isOutOfNewWords ? onChooseTopics() : start(.daily) }
                )
                .padding(.top, Spacing.m)
            }
            .padding(.horizontal, Spacing.screenGutter)
            .padding(.top, Spacing.m)
            .padding(.bottom, Spacing.l)
        }
        .refreshable {
            async let learnerRefresh: Void = learner.refresh()
            async let mapRefresh: Void = challengeMap.refresh()
            _ = await (learnerRefresh, mapRefresh)
        }
        // Never mid-session (Home isn't on screen then), at most once per launch.
        .task(id: learner.home?.reviewLoad?.promptChoice) {
            if learner.shouldOfferReviewChoice, !practice.isActive { isChoosingReviewLoad = true }
        }
        .sheet(isPresented: $isChoosingReviewLoad, onDismiss: {
            Task { await learner.acknowledgeReviewChoice() }
        }) {
            if let load = learner.home?.reviewLoad {
                ReviewLoadChoiceSheet(
                    load: load,
                    goal: learner.profile?.settings.dailyNewWordGoal ?? plan.current.wordsPerDay,
                    onExtraReview: { startReviewOnly() },
                    onLower: { value, mode in try await learner.setNewWordOverride(value: value, mode: mode) }
                )
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .presentationBackground(Color.canvas)
            }
        }
    }

    private var isOutOfNewWords: Bool {
        challengeMap.map?.newWordsBlockedReason == .scopeExhausted
            || DailyLessonStatus(home: learner.home, goal: plan.current.wordsPerDay).scope == .exhaustedNoCustom
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
        let status = DailyLessonStatus(home: learner.home, goal: plan.current.wordsPerDay)
        return VStack(alignment: .leading, spacing: Spacing.l) {
            HStack(alignment: .bottom, spacing: Spacing.m) {
                VStack(alignment: .leading, spacing: Spacing.m) {
                    HStack(spacing: Spacing.xs) {
                        Text("Today’s session")
                            .font(Typography.emphasis)
                            .foregroundStyle(Color.ink)
                        lessonInfoButton(status)
                    }
                    StatRow(label: "Words to review", value: status.sessionReviews)
                    StatRow(label: "New words", value: status.newWords)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                LessonMascot()
            }
            actions(status, due: due)
        }
        .padding(Spacing.m + 2)
        .cardSurface()
    }

    private var topicNames: String {
        TopicCatalog.topics(ids: plan.current.topicIDs).map(\.name)
            .formatted(.list(type: .and).locale(AppLanguage.active.locale))
    }

    /// The card shows only this session's counts; why it looks this way (scope, lowered goal, backlog) sits behind ⓘ.
    @ViewBuilder
    private func lessonInfoButton(_ status: DailyLessonStatus) -> some View {
        let lines = noteLines(status)
        if !lines.isEmpty {
            Button {
                isShowingLessonInfo = true
            } label: {
                Image(systemName: "info.circle")
                    .font(Typography.secondary.weight(.semibold))
                    .foregroundStyle(Color.mutedInk)
                    .frame(minWidth: Spacing.minTouchTarget, minHeight: Spacing.minTouchTarget)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel(Text("About today’s session"))
            .popover(isPresented: $isShowingLessonInfo) {
                lessonInfo(lines, status: status)
                    .presentationCompactAdaptation(.popover)
            }
        }
    }

    private func lessonInfo(_ lines: [Text], status: DailyLessonStatus) -> some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                line
                    .font(Typography.secondary)
                    .foregroundStyle(Color.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if case .low = status.scope, !plan.current.hasAllTopics {
                Button {
                    isShowingLessonInfo = false
                    onChooseTopics()
                } label: {
                    Text("Add topics")
                        .font(Typography.micro.weight(.heavy))
                        .foregroundStyle(Color.selectedInk)
                        .frame(minHeight: Spacing.minTouchTarget)
                }
            }
        }
        .padding(Spacing.m)
        .frame(width: 280, alignment: .leading)
    }

    private func noteLines(_ status: DailyLessonStatus) -> [Text] {
        var lines: [Text] = []
        switch status.scope {
        case .exhaustedNoCustom:
            lines.append(plan.current.hasAllTopics
                ? Text("You’ve learned every new word in \(topicNames). You can still review and practise them. Choose another collection to learn new words.")
                : Text("You’ve learned every new word in \(topicNames). You can still review and practise them. Choose another topic or collection to learn new words."))
        case .exhaustedWithCustom(let custom):
            lines.append(Text("No new words left in your topics. \(custom) words you added are still to learn."))
        case .low(let remaining, let sessions):
            lines.append(Text("\(remaining) new words left, about \(sessions) sessions"))
        case .ok:
            break
        }
        switch status.reason {
        case .userOverride(let until):
            if let until {
                lines.append(Text("\(status.newWords) new words today (lowered until \(until.formatted(.dateTime.weekday(.wide).locale(AppLanguage.active.locale))))"))
            } else {
                lines.append(Text("\(status.newWords) new words today (lowered until fewer words are waiting)"))
            }
        case .autoBalanced:
            lines.append(Text("\(status.newWords) new words today, balanced with your reviews"))
        case .scopeLimited:
            if case .ok = status.scope { lines.append(Text("Only \(status.newWords) new words left today in \(topicNames)")) }
        case .none:
            break
        }
        if status.backlog > status.sessionReviews {
            lines.append(Text("\(status.backlog) words waiting for review"))
        }
        return lines
    }

    @ViewBuilder
    private func actions(_ status: DailyLessonStatus, due: Int) -> some View {
        if case .exhaustedNoCustom = status.scope {
            VStack(spacing: Spacing.s) {
                if due > 0 {
                    PrimaryButton(title: "Review \(status.sessionReviews) words", shimmers: true) { startReviewOnly() }
                } else {
                    PrimaryButton(title: "Practise", shimmers: true, action: onOpenRandomPractice)
                }
                // Every topic of the collection is already chosen: only another collection brings new words.
                if !plan.current.hasAllTopics {
                    SecondaryButton(title: "Choose topics", action: onChooseTopics)
                }
                SecondaryButton(title: "Change collection", action: onChooseTopics)
            }
        } else {
            VStack(spacing: Spacing.s) {
                PrimaryButton(title: due > 0 ? "Start" : "Start Flow", shimmers: true) { start(.daily) }
                if status.backlog > ReviewLoad.statusThreshold {
                    SecondaryButton(title: "Extra review") { startReviewOnly() }
                }
            }
        }
    }

    private func startReviewOnly() {
        Task { await practice.startReviewOnly() }
    }

    private func start(_ mode: SessionMode, challengeID: String? = nil) {
        Task { await practice.start(mode, challengeID: challengeID) }
    }
}

// MARK: - Daily lesson status

/// What the Daily Lesson card says, from `GET /me/learn-home`. Without the newer blocks it shows the goal as before.
struct DailyLessonStatus: Equatable {
    enum Scope: Equatable {
        case ok
        /// Less than one week of new words left.
        case low(remaining: Int, sessions: Int)
        case exhaustedWithCustom(Int)
        case exhaustedNoCustom
    }

    enum Reason: Equatable {
        case userOverride(until: Date?)
        case autoBalanced
        /// Fewer new words than chosen because that's all the scope holds.
        case scopeLimited
    }

    let newWords: Int
    let backlog: Int
    /// Reviews the next daily session holds: the backlog up to the planner's cap.
    let sessionReviews: Int
    let scope: Scope
    let reason: Reason?

    init(home: LearnHome?, goal: Int) {
        let load = home?.reviewLoad
        newWords = load?.effectiveNewPerSession ?? goal
        backlog = load?.backlog ?? home?.dueCount ?? 0
        let due = home?.dueCount ?? backlog
        sessionReviews = load.map { min(due, $0.dueCap) } ?? due
        switch home?.scope {
        case let scope? where scope.status == .exhausted:
            self.scope = scope.pendingCustomMeanings > 0 ? .exhaustedWithCustom(scope.pendingCustomMeanings) : .exhaustedNoCustom
        case let scope? where scope.status == .low:
            self.scope = .low(remaining: scope.remainingNewMeanings, sessions: scope.sessionsLeftEstimate ?? 1)
        default:
            self.scope = .ok
        }
        switch load?.newWordReason {
        case .userOverride?: reason = .userOverride(until: load?.override?.mode == .untilDate ? load?.override?.until : nil)
        case .autoBalanced?: reason = .autoBalanced
        case .scopeLimited?: reason = .scopeLimited
        default: reason = nil
        }
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
