import SwiftUI

/// Practice scaffold shared by every template: question → prompt → exercise → feedback → pinned action.
struct TaskScaffold<Content: View, Action: View>: View {
    let attempt: TaskAttempt
    /// Replaces the attempt's own feedback, for a result that doesn't change its status (Recording).
    var feedback: FeedbackCopy? = nil
    @ViewBuilder let content: Content
    @ViewBuilder let action: Action

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.l) {
                if let question = attempt.task.question {
                    ExerciseHeading(title: Text(verbatim: question))
                }
                TaskPromptView(attempt: attempt)

                // While a wrong answer is shown, the exercise waits for "Try again" or "Continue".
                content
                    .allowsHitTesting(attempt.status != .wrong && attempt.status != .exhausted)
            }
            .padding(.horizontal, Spacing.screenGutter)
            .padding(.top, Spacing.m)
            .padding(.bottom, Spacing.l)
        }
        .scrollDismissesKeyboard(.interactively)
        .safeAreaInset(edge: .bottom) {
            FeedbackActionPanel(feedback: feedback ?? TaskFeedbackCopy.make(attempt)) { action }
        }
    }
}

/// A task has at most one prompt kind. Audio stays audio: showing the text would give the answer away.
struct TaskPromptView: View {
    let attempt: TaskAttempt
    @Environment(PracticeSessionStore.self) private var store

    var body: some View {
        switch attempt.task.prompt {
        case nil:
            EmptyView()
        case .text(let text, let highlight)?:
            promptText(text, highlight: highlight)
                .font(Typography.challengeTerm)
                .foregroundStyle(Color.ink)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Spacing.s)
        case .audio?:
            VStack(spacing: Spacing.s) {
                AudioPlayButton(isSpeaking: store.audio.isPlaying, isAvailable: true, isLarge: true) {
                    Task { await store.playPromptAudio() }
                }
                if store.audioFailed {
                    Text("Sound didn’t play. Try again, or answer without it.")
                        .font(Typography.micro)
                        .foregroundStyle(Color.errorInk)
                        .multilineTextAlignment(.center)
                }
            }
            .frame(maxWidth: .infinity)
        }
    }

    private func promptText(_ text: String, highlight: PromptHighlight?) -> Text {
        guard let parts = highlight?.split(text) else { return Text(verbatim: text) }
        return Text(verbatim: parts.before)
            + Text(verbatim: parts.word).foregroundColor(Color.interactive).underline()
            + Text(verbatim: parts.after)
    }
}

/// Feedback never names the answer until the task is finished.
enum TaskFeedbackCopy {
    static func make(_ attempt: TaskAttempt) -> FeedbackCopy? {
        let answer = attempt.solutionText
        switch attempt.status {
        case .answering, .recorded:
            return nil
        case .solved:
            return FeedbackCopy(kind: .success, title: String(localized: "Correct!"),
                                message: answer ?? String(localized: "All pairs matched."))
        case .wrong:
            return FeedbackCopy(kind: .error, title: String(localized: "Not quite"),
                                message: String(localized: "Try again, or show the answer."))
        case .revealed:
            return FeedbackCopy(kind: .info, title: String(localized: "Here’s the answer"),
                                message: answer ?? String(localized: "The correct pairs are shown below."))
        case .exhausted:
            // The exercise keeps the learner's work; this panel is the only place the answer appears.
            return FeedbackCopy(kind: .info, title: String(localized: "The correct answer"),
                                message: answer ?? attempt.missedPairsText ?? "")
        }
    }
}

/// Check while answering, Try again after a miss, Continue once finished.
struct TaskActionBar: View {
    let attempt: TaskAttempt
    var checkTitle: LocalizedStringKey = "Check"
    var canCheck = false
    /// Status line shown in place of Check when there is none (Match submits pair by pair).
    var requirement: LocalizedStringKey?
    var onCheck: (() -> Void)?
    /// Offers "Show answer" here. Off where `HintControl` already does.
    var showsReveal = true

    @Environment(PracticeSessionStore.self) private var store
    @Environment(\.motion) private var motion

    var body: some View {
        VStack(spacing: Spacing.s) {
            if attempt.isFinished {
                PrimaryButton(title: "Continue") {
                    motion.perform(MotionTokens.transition) { store.advance() }
                }
            } else if attempt.status == .wrong {
                revealButton
                PrimaryButton(title: "Try again") {
                    withAnimation(motion.travel(MotionTokens.returnToOrigin)) { store.tryAgain() }
                }
            } else {
                if showsReveal {
                    revealButton
                }
                if let onCheck {
                    PrimaryButton(title: checkTitle, isEnabled: canCheck, action: onCheck)
                } else if let requirement {
                    Text(requirement)
                        .font(Typography.secondary)
                        .foregroundStyle(Color.mutedInk)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity, minHeight: Spacing.minTouchTarget)
                }
            }
        }
    }

    @ViewBuilder
    private var revealButton: some View {
        if attempt.canReveal {
            Button {
                store.reveal()
            } label: {
                Text("Show answer")
                    .font(Typography.secondary.weight(.bold))
                    .foregroundStyle(Color.mutedInk)
                    .frame(minHeight: Spacing.minTouchTarget)
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }
}
