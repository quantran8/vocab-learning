import SwiftUI

/// Plays one Lab template. Same task views as a live session, hosted under the Lab's own store.
struct LabTaskView: View {
    @Environment(TemplateSandboxStore.self) private var sandbox
    @Environment(\.motion) private var motion

    var body: some View {
        let session = sandbox.session
        ZStack {
            if case .practice(_, let task)? = session.currentStep, let attempt = session.attempts[task.id] {
                PracticeTaskView(attempt: attempt)
                    .id(session.stepIndex)
                    .transition(motion.stepTransition)
            }
        }
        .safeAreaInset(edge: .top) {
            FlowHeader(
                stage: "Practice Lab",
                stageCurrent: session.stepIndex + 1,
                stageTotal: session.steps.count,
                step: session.stepIndex + 1,
                totalSteps: session.steps.count,
                closeLabel: "Back to Lab",
                onClose: { motion.perform(MotionTokens.transition) { sandbox.closeTemplate() } }
            )
            .padding(.horizontal, Spacing.screenGutter)
            .padding(.vertical, Spacing.xs)
            .background(Color.canvas)
        }
        .environment(session)
    }
}
