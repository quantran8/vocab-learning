import SwiftUI

/// Everything between tapping a practice button and returning Home.
struct PracticeSessionView: View {
    @Environment(PracticeSessionStore.self) private var store
    @Environment(\.motion) private var motion

    var body: some View {
        switch store.stage {
        case .idle:
            EmptyView()
        case .planning:
            StatusScreen(title: "Preparing your session", isBusy: true)
        case .committing:
            StatusScreen(title: "Saving your progress", isBusy: true)
        case .empty:
            StatusScreen(title: "Nothing to practise right now", message: Text("Check back after learning more words.")) {
                closeButton
            }
        case .reviewPreview(let words):
            ReviewPreviewView(words: words)
        case .reviewFinished:
            StatusScreen(title: "Review complete", message: Text("Next up: some new words to learn.")) {
                PrimaryButton(title: "Learn new words") {
                    motion.perform(MotionTokens.transition) { store.continueToPractice() }
                }
            }
        case .running:
            PracticeFlowView()
        case .finished(let summary):
            PracticeResultsView(summary: summary)
        case .failed(.planning(let message)):
            StatusScreen(title: "Couldn’t start the session", message: Text(verbatim: message)) {
                retryButton("Try again")
                closeButton
            }
        case .failed(.commit(let message)):
            StatusScreen(title: "Your progress isn’t saved yet", message: Text(verbatim: message)) {
                retryButton("Try saving again")
            }
        case .failed(.sessionLost(let message)):
            StatusScreen(title: "Session ended", message: Text(verbatim: message)) {
                closeButton
            }
        }
    }

    private var closeButton: some View {
        SecondaryButton(title: "Back to home") {
            motion.perform(MotionTokens.transition) { store.close() }
        }
    }

    private func retryButton(_ title: LocalizedStringKey) -> some View {
        PrimaryButton(title: title) {
            Task { await store.retry() }
        }
    }
}

/// Centered status with optional spinner and actions. Also used while the account loads.
struct StatusScreen<Actions: View>: View {
    let title: LocalizedStringKey
    var message: Text?
    var isBusy = false
    @ViewBuilder var actions: Actions

    var body: some View {
        VStack(spacing: Spacing.m) {
            Spacer()
            if isBusy {
                ProgressView()
                    .controlSize(.large)
            }
            Text(title)
                .font(Typography.screenTitle)
                .tracking(Typography.tightTracking)
                .foregroundStyle(Color.ink)
                .multilineTextAlignment(.center)
                .accessibilityAddTraits(.isHeader)
            message
                .font(Typography.secondary)
                .foregroundStyle(Color.mutedInk)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            Spacer()
            VStack(spacing: Spacing.s) {
                actions
            }
        }
        .padding(.horizontal, Spacing.screenGutter)
        .padding(.bottom, Spacing.m)
    }
}

extension StatusScreen where Actions == EmptyView {
    init(title: LocalizedStringKey, message: Text? = nil, isBusy: Bool = false) {
        self.init(title: title, message: message, isBusy: isBusy) { EmptyView() }
    }
}

/// Lists the session's review words before its first step: the intro streams in, then the words land in rows,
/// with an entrance picked at random each time.
/// Presentation only: Continue works at any point.
private struct ReviewPreviewView: View {
    let words: [ReviewWord]
    @Environment(PracticeSessionStore.self) private var store
    @Environment(\.motion) private var motion
    @State private var hasLanded = false
    @State private var entrance = Entrance.allCases.randomElement() ?? .scattered
    @State private var trainOrigin = ReviewPreviewView.trainOrigins.randomElement() ?? .zero
    /// Bumped per word to replay its wiggle.
    @State private var wiggles: [String: Int] = [:]

    private enum Entrance: CaseIterable {
        case scattered, wordTrain
    }

    private static let tileHeight: CGFloat = 54
    /// Top, right, bottom and left, each past that screen edge on any phone.
    private static let trainOrigins = [
        CGSize(width: 0, height: -1000),
        CGSize(width: 460, height: 0),
        CGSize(width: 0, height: 1000),
        CGSize(width: -460, height: 0),
    ]
    /// Where tiles start, cycled so neighbours arrive from different sides.
    private static let flyInOrigins = [
        CGSize(width: -420, height: -120),
        CGSize(width: 420, height: -260),
        CGSize(width: -260, height: 520),
        CGSize(width: 360, height: 420),
        CGSize(width: 40, height: -560),
        CGSize(width: -440, height: 260),
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text("Words to review")
                    .font(Typography.screenTitle)
                    .tracking(Typography.tightTracking)
                    .foregroundStyle(Color.ink)
                    .accessibilityAddTraits(.isHeader)

                StreamingText(text: String(localized: "Let’s review these words you already learned before exploring new words.")) {
                    hasLanded = true
                }
                .font(Typography.body)
                .foregroundStyle(Color.mutedInk)
                .padding(.top, Spacing.xs)

                FlowLayout(spacing: Spacing.xs, lineSpacing: Spacing.xs, alignment: .leading) {
                    ForEach(Array(words.enumerated()), id: \.element.id) { index, word in
                        tile(word, index: index)
                            .modifier(TileWiggle(trigger: wiggles[word.id, default: 0]))
                    }
                }
                .padding(.top, Spacing.l)
            }
            .padding(.horizontal, Spacing.screenGutter)
            .padding(.top, Spacing.m)
            .padding(.bottom, Spacing.l)
        }
        .task(id: hasLanded) { await wiggleWords() }
        .safeAreaInset(edge: .bottom) {
            PinnedActionBar {
                VStack(spacing: Spacing.s) {
                    PrimaryButton(title: "Continue") {
                        motion.perform(MotionTokens.transition) { store.continueToPractice() }
                    }
                    SecondaryButton(title: "Back to home") {
                        motion.perform(MotionTokens.transition) { store.close() }
                    }
                }
            }
        }
    }

    /// After the entrance, a random word stirs every so often until the screen goes away.
    private func wiggleWords() async {
        guard hasLanded, !motion.reduceMotion else { return }
        try? await Task.sleep(for: .seconds(entranceDuration + MotionTokens.reviewSettle))
        while !Task.isCancelled {
            if let word = words.randomElement() {
                wiggles[word.id, default: 0] += 1
            }
            try? await Task.sleep(for: .seconds(Double.random(in: MotionTokens.reviewWigglePause)))
        }
    }

    private var entranceDuration: Double {
        switch entrance {
        case .scattered: Double(words.count) * MotionTokens.reviewTileStagger
        case .wordTrain: Double(words.count) * MotionTokens.reviewTrainStagger
        }
    }

    @ViewBuilder
    private func tile(_ word: ReviewWord, index: Int) -> some View {
        switch entrance {
        case .scattered:
            let tilt: Double = motion.reduceMotion ? 0 : (index.isMultiple(of: 2) ? -12 : 12)
            tileFace(Text(verbatim: word.lemma))
                .rotationEffect(.degrees(hasLanded ? 0 : tilt))
                .offset(hasLanded ? .zero : flyInOrigin(index))
                .opacity(hasLanded ? 1 : 0)
                .animation(
                    motion.animation(MotionTokens.reviewTileLanding.delay(Double(index) * MotionTokens.reviewTileStagger)),
                    value: hasLanded
                )
        case .wordTrain:
            // All come from the same side, so each word follows the tail of the one before.
            tileFace(Text(verbatim: word.lemma))
                .offset(hasLanded || motion.reduceMotion ? .zero : trainOrigin)
                .opacity(hasLanded ? 1 : 0)
                .animation(
                    motion.animation(MotionTokens.reviewTrainLanding.delay(Double(index) * MotionTokens.reviewTrainStagger)),
                    value: hasLanded
                )
        }
    }

    private func flyInOrigin(_ index: Int) -> CGSize {
        motion.reduceMotion ? .zero : Self.flyInOrigins[index % Self.flyInOrigins.count]
    }

    private func tileFace(_ label: some View) -> some View {
        let shape = RoundedRectangle(cornerRadius: Radii.chip, style: .continuous)
        return label
            .font(Typography.tileLarge)
            .foregroundStyle(Color.ink)
            .padding(.horizontal, Spacing.m + Spacing.xxs)
            .frame(minHeight: Self.tileHeight)
            .background(Color.surface, in: shape)
            .overlay(shape.strokeBorder(Color.stroke, lineWidth: 1.5))
            .background(shape.fill(Color.tileDepth).offset(y: Spacing.tileDepth))
            .padding(.bottom, Spacing.tileDepth)
    }
}

/// One quick shake with a small hop, replayed whenever `trigger` changes.
private struct TileWiggle: ViewModifier {
    let trigger: Int

    private struct Frame {
        var angle: Double = 0
        var lift: CGFloat = 0
    }

    func body(content: Content) -> some View {
        content.keyframeAnimator(initialValue: Frame(), trigger: trigger) { view, frame in
            view
                .rotationEffect(.degrees(frame.angle))
                .offset(y: frame.lift)
        } keyframes: { _ in
            KeyframeTrack(\.angle) {
                CubicKeyframe(-6, duration: 0.09)
                CubicKeyframe(5, duration: 0.11)
                CubicKeyframe(-4, duration: 0.1)
                CubicKeyframe(2, duration: 0.09)
                CubicKeyframe(0, duration: 0.11)
            }
            KeyframeTrack(\.lift) {
                CubicKeyframe(-5, duration: 0.14)
                CubicKeyframe(0, duration: 0.2)
            }
        }
    }
}

/// Reveals its text character by character. The hidden rest keeps its space, so lines never reflow.
private struct StreamingText: View {
    let text: String
    let onFinished: () -> Void
    @Environment(\.motion) private var motion
    @State private var revealed = 0

    var body: some View {
        Text(attributed)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityLabel(Text(verbatim: text))
            .task {
                if !motion.reduceMotion {
                    while revealed < text.count {
                        revealed += 1
                        try? await Task.sleep(for: .seconds(MotionTokens.streamCharacter))
                        if Task.isCancelled { return }
                    }
                }
                revealed = text.count
                onFinished()
            }
    }

    private var attributed: AttributedString {
        var hidden = AttributedString(String(text.dropFirst(revealed)))
        hidden.foregroundColor = Color.clear
        return AttributedString(String(text.prefix(revealed))) + hidden
    }
}

/// One persistent header for every step; the step below it transitions.
private struct PracticeFlowView: View {
    @Environment(PracticeSessionStore.self) private var store
    @Environment(\.motion) private var motion
    @State private var isConfirmingExit = false

    var body: some View {
        ZStack {
            if let step = store.currentStep {
                stepView(step)
                    .id(store.stepIndex)
                    .transition(motion.stepTransition)
            }
        }
        .safeAreaInset(edge: .top) {
            FlowHeader(
                stage: "Practice",
                stageCurrent: store.stepIndex + 1,
                stageTotal: store.steps.count,
                step: store.stepIndex + 1,
                totalSteps: store.steps.count,
                onClose: { isConfirmingExit = true }
            )
            .padding(.horizontal, Spacing.screenGutter)
            .padding(.vertical, Spacing.xs)
            .background(Color.canvas)
        }
        .confirmationDialog("Leave this flow?", isPresented: $isConfirmingExit, titleVisibility: .visible) {
            Button("Leave without saving", role: .destructive) {
                motion.perform(MotionTokens.transition) { store.close() }
            }
            Button("Keep practising", role: .cancel) {}
        } message: {
            Text("Progress only counts once the whole session is finished.")
        }
    }

    @ViewBuilder
    private func stepView(_ step: PlanStep) -> some View {
        switch step {
        case .learn(_, let card):
            LearnCardStep(card: card)
        case .practice(_, let task):
            if let attempt = store.attempts[task.id] {
                PracticeTaskView(attempt: attempt)
            }
        }
    }
}

/// Picks the view for a task's template. Shared by live sessions and Practice Lab.
struct PracticeTaskView: View {
    let attempt: TaskAttempt

    var body: some View {
        switch attempt.task.template {
        case .select: ChoiceTaskView(attempt: attempt)
        case .clozeSelect: ClozeTaskView(attempt: attempt)
        case .typing: TypingTaskView(attempt: attempt)
        case .flyReorder: ReorderTaskView(attempt: attempt)
        case .match: MatchTaskView(attempt: attempt)
        case .surgery: SurgeryTaskView(attempt: attempt)
        case .recording: RecordingTaskView(attempt: attempt)
        }
    }
}

private struct LearnCardStep: View {
    let card: LearnCard
    @Environment(PracticeSessionStore.self) private var store
    @Environment(\.motion) private var motion

    var body: some View {
        let word = VocabularyItem(
            id: card.word,
            term: card.word,
            meaningVi: card.meaning,
            example: card.examples?.first?.text ?? "",
            definitionEN: card.definition,
            ipa: card.ipa
        )
        ScrollView {
            WordIntroContent(
                word: word,
                presentation: word.introPresentation,
                playAudio: card.audio.map { clip in { store.playClip(clip) } }
            )
            .padding(.horizontal, Spacing.screenGutter)
            .padding(.top, Spacing.xl)
            .padding(.bottom, Spacing.l)
        }
        .safeAreaInset(edge: .bottom) {
            PinnedActionBar {
                PrimaryButton(title: "Continue") {
                    motion.perform(MotionTokens.transition) { store.advance() }
                }
            }
        }
    }
}

struct PracticeResultsView: View {
    let summary: CommitSummary
    @Environment(PracticeSessionStore.self) private var store
    @Environment(\.motion) private var motion

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                BrandBar()

                Chip(text: "Flow complete", fill: .reward)
                    .padding(.top, Spacing.xl + Spacing.xs)

                Text("Nice work.")
                    .font(Typography.display)
                    .tracking(-1.4)
                    .foregroundStyle(Color.ink)
                    .multilineTextAlignment(.center)
                    .accessibilityAddTraits(.isHeader)
                    .padding(.top, Spacing.s)

                LazyVGrid(columns: [GridItem(.flexible(), spacing: Spacing.s), GridItem(.flexible())], spacing: Spacing.s) {
                    stat("Exercises done", value: summary.practiceTasks)
                    stat("Right first time", value: store.firstTryCount)
                    stat("Meanings reviewed", value: summary.reviewedMeanings)
                    stat("New words", value: summary.newWordGoalSlots)
                }
                .padding(.top, Spacing.xl)
            }
            .padding(.horizontal, Spacing.screenGutter + 4)
            .padding(.top, Spacing.s)
            .padding(.bottom, Spacing.l)
        }
        .safeAreaInset(edge: .bottom) {
            PinnedActionBar {
                PrimaryButton(title: "Back to home") {
                    motion.perform(MotionTokens.transition) { store.close() }
                }
            }
        }
    }

    private func stat(_ label: LocalizedStringKey, value: Int) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            Text(value, format: .number)
                .font(Typography.screenTitle.monospacedDigit())
                .foregroundStyle(Color.ink)
            Text(label)
                .font(Typography.micro)
                .foregroundStyle(Color.mutedInk)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.l - 4)
        .cardSurface(radius: Radii.tile)
        .accessibilityElement(children: .combine)
    }
}
