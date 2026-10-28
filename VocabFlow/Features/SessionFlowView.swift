import Observation
import SwiftUI

/// Ephemeral, per-step UI input shared between a stage's content and the pinned action.
/// Reset whenever the step advances; never part of the scored session.
@Observable
@MainActor
final class FlowDraft {
    /// The tile currently placed in the Build blank.
    var selectedTileID: String?
    var isDragging = false
    var recallText = ""

    func reset() {
        selectedTileID = nil
        isDragging = false
        recallText = ""
    }
}

/// One persistent frame for Learn → Build → Recall. The header and pinned action stay mounted;
/// only the stage content is swapped (and transitioned) when the phase changes.
struct SessionFlowView: View {
    @Environment(SessionStore.self) private var store
    @Environment(\.motion) private var motion
    @State private var draft = FlowDraft()
    @State private var isConfirmingExit = false

    private static let topAnchor = "flowTop"

    var body: some View {
        let phase = store.state.phase
        let progress = store.flowProgress
        let stage = stageInfo(phase)

        ScrollViewReader { proxy in
            ScrollView {
                Color.clear.frame(height: 0).id(Self.topAnchor)
                ZStack(alignment: .top) {
                    stageContent(phase)
                        .id(phase)
                        .transition(motion.stepTransition)
                }
                .padding(.horizontal, Spacing.screenGutter)
                .padding(.top, Spacing.xl)
                .padding(.bottom, Spacing.l)
            }
            .scrollDisabled(draft.isDragging)
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: phase) {
                proxy.scrollTo(Self.topAnchor, anchor: .top)
            }
        }
        .safeAreaInset(edge: .top) {
            FlowHeader(
                title: progress.stage == .learn ? "Meet the words" : "Practice",
                stage: stage.label,
                stageCurrent: stage.current,
                stageTotal: stage.total,
                step: progress.current,
                totalSteps: progress.total,
                onClose: { isConfirmingExit = true }
            )
            // New stage, new progress: the bar starts fresh instead of animating backwards.
            .id(progress.stage)
            .padding(.horizontal, Spacing.screenGutter)
            .padding(.vertical, Spacing.xs)
            .background(Color.canvas)
        }
        .safeAreaInset(edge: .bottom) {
            FeedbackActionPanel(feedback: SessionFeedbackCopy.make(phase: phase, store: store)) {
                FlowActionBar(phase: phase)
            }
        }
        .environment(draft)
        .confirmationDialog("Leave this flow?", isPresented: $isConfirmingExit, titleVisibility: .visible) {
            Button("Leave and reset", role: .destructive) {
                draft.reset()
                motion.perform(MotionTokens.transition) { store.restart() }
            }
            Button("Keep practising", role: .cancel) {}
        } message: {
            Text("Your current session will reset.")
        }
    }

    @ViewBuilder
    private func stageContent(_ phase: SessionPhase) -> some View {
        switch phase {
        case .learn(let index): LearnView(index: index)
        case .build(let index): BuildView(index: index)
        case .recall(let index): RecallView(index: index)
        case .home, .results: EmptyView()
        }
    }

    private func stageInfo(_ phase: SessionPhase) -> (label: LocalizedStringKey, current: Int, total: Int) {
        switch phase {
        case .learn(let index): ("Learn", index + 1, store.content.words.count)
        case .build(let index): ("Build", index + 1, store.content.buildChallenges.count)
        case .recall(let index): ("Recall", index + 1, store.content.recallPrompts.count)
        case .home, .results: ("", 0, 0)
        }
    }
}

/// The single pinned action for the flow. Same button instance across steps; only its title/state change.
private struct FlowActionBar: View {
    let phase: SessionPhase
    @Environment(SessionStore.self) private var store
    @Environment(FlowDraft.self) private var draft
    @Environment(\.motion) private var motion

    var body: some View {
        switch phase {
        case .learn(let index):
            PrimaryButton(title: index + 1 >= store.totalWords ? "Start practice" : "Next word") {
                advance { store.finishLearning() }
            }
        case .build(let index):
            buildAction(index)
        case .recall(let index):
            recallAction(index)
        case .home, .results:
            EmptyView()
        }
    }

    @ViewBuilder
    private func buildAction(_ index: Int) -> some View {
        if store.isBuildCompleted(index: index) {
            let isLast = index + 1 >= store.content.buildChallenges.count
            PrimaryButton(title: isLast ? "Continue to recall" : "Continue") {
                advance { store.next() }
            }
        } else if case .buildIncorrect = store.state.feedback {
            tryAgain {
                draft.selectedTileID = nil
            }
        } else {
            let selected = draft.selectedTileID
            PrimaryButton(
                title: "Check answer",
                requirement: "Tap a word or drag it into the sentence.",
                isEnabled: selected != nil
            ) {
                guard let selected else { return }
                // The tile stays in the slot; it turns green or red from the evaluation.
                store.submitBuild(tileID: selected)
            }
        }
    }

    @ViewBuilder
    private func recallAction(_ index: Int) -> some View {
        let wordID = store.recallPrompt(at: index)?.wordID ?? ""
        if store.recallOutcome(wordID: wordID) != nil {
            let isLast = index + 1 >= store.content.recallPrompts.count
            PrimaryButton(title: isLast ? "See results" : "Continue") {
                advance { store.next() }
            }
        } else if case .recallIncorrect = store.state.feedback {
            tryAgain {
                draft.recallText = ""
            }
        } else {
            PrimaryButton(
                title: "Check answer",
                requirement: "Type a word to check.",
                isEnabled: !AnswerEvaluator.normalize(draft.recallText).isEmpty
            ) {
                store.submitRecall(text: draft.recallText)
            }
        }
    }

    /// After a wrong answer: clears the step's input and feedback so it can be answered fresh.
    /// Attempts and hints already used stay recorded in the session.
    private func tryAgain(reset: @escaping () -> Void) -> some View {
        PrimaryButton(title: "Try again", systemImage: "arrow.counterclockwise") {
            withAnimation(motion.travel(MotionTokens.returnToOrigin)) {
                reset()
                store.dismissFeedback()
            }
        }
    }

    /// Clears step input before the phase changes so the next step never sees stale input.
    private func advance(_ body: () -> Void) {
        draft.reset()
        motion.perform(MotionTokens.transition, body)
    }
}
