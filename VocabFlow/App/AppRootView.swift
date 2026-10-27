import SwiftUI

struct AppRootView: View {
    @Environment(SessionStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let motion = MotionCoordinator(reduceMotion: reduceMotion)
        ZStack {
            Color.canvas.ignoresSafeArea()
            screen
                .id(RouteID(phase: store.state.phase, session: store.sessionToken))
                .transition(motion.routeTransition)
        }
        .fontDesign(.rounded)
        .environment(\.motion, motion)
        .preferredColorScheme(.light)
    }

    @ViewBuilder
    private var screen: some View {
        switch store.state.phase {
        case .home: HomeView()
        case .learn(let index): LearnView(index: index)
        case .build(let index): BuildView(index: index)
        case .recall(let index): RecallView(index: index)
        case .results: ResultsView()
        }
    }
}

private struct RouteID: Hashable {
    let phase: SessionPhase
    let session: UUID
}

#Preview {
    AppRootView()
        .environment(SessionStore(content: DemoContentRepository().loadOrFail(), haptics: NoOpFeedback()))
}
