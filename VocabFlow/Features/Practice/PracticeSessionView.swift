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
