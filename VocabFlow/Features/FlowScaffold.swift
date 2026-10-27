import SwiftUI

struct FlowScaffold<Content: View, Action: View>: View {
    let stage: LocalizedStringKey
    let stageCurrent: Int
    let stageTotal: Int
    var isScrollDisabled = false
    @ViewBuilder let content: Content
    @ViewBuilder let action: Action

    @Environment(SessionStore.self) private var store
    @Environment(\.motion) private var motion
    @State private var isConfirmingExit = false

    var body: some View {
        let step = store.flowStep
        ScrollView {
            content
                .padding(.horizontal, Spacing.screenGutter)
                .padding(.top, Spacing.xl)
                .padding(.bottom, Spacing.l)
        }
        .scrollDisabled(isScrollDisabled)
        .scrollDismissesKeyboard(.interactively)
        .safeAreaInset(edge: .top) {
            FlowHeader(
                stage: stage,
                stageCurrent: stageCurrent,
                stageTotal: stageTotal,
                step: step.current,
                totalSteps: step.total,
                onClose: { isConfirmingExit = true }
            )
            .padding(.horizontal, Spacing.screenGutter)
            .padding(.vertical, Spacing.xs)
            .background(Color.canvas)
        }
        .safeAreaInset(edge: .bottom) {
            PinnedActionBar { action }
        }
        .confirmationDialog("Leave this flow?", isPresented: $isConfirmingExit, titleVisibility: .visible) {
            Button("Leave and reset", role: .destructive) {
                motion.perform(MotionTokens.transition) { store.restart() }
            }
            Button("Keep practising", role: .cancel) {}
        } message: {
            Text("Your current session will reset.")
        }
    }
}
