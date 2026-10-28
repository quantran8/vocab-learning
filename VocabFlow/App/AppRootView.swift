import SwiftUI

struct AppRootView: View {
    @Environment(SessionStore.self) private var store
    @Environment(TemplateSandboxStore.self) private var sandbox
    @Environment(LearningPlanStore.self) private var plan
    @Environment(AppSettingsStore.self) private var settings
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let motion = MotionCoordinator(reduceMotion: reduceMotion || settings.reduceMotion)
        ZStack {
            Color.canvas.ignoresSafeArea()
            screen
                .id(route)
                .transition(motion.routeTransition)
        }
        .environment(\.motion, motion)
        .preferredColorScheme(.light)
    }

    private var route: RouteID {
        if !plan.hasCompletedOnboarding {
            return .onboarding
        }
        if sandbox.isOpen {
            return .lab(template: sandbox.activeTemplate)
        }
        switch store.state.phase {
        case .home: return .home(token: store.sessionToken)
        // One identity for the whole flow: header and action stay mounted, content transitions inside.
        case .learn, .build, .recall: return .flow(token: store.sessionToken)
        case .results: return .results(token: store.sessionToken)
        }
    }

    @ViewBuilder
    private var screen: some View {
        if !plan.hasCompletedOnboarding {
            OnboardingView()
        } else if sandbox.isOpen {
            if sandbox.activeTemplate != nil {
                TemplateHostView()
            } else {
                PracticeLabView()
            }
        } else {
            switch store.state.phase {
            case .home: MainShellView()
            case .learn, .build, .recall: SessionFlowView()
            case .results: ResultsView()
            }
        }
    }
}

private enum RouteID: Hashable {
    case onboarding
    case home(token: UUID)
    case flow(token: UUID)
    case results(token: UUID)
    case lab(template: TemplateKind?)
}

#Preview {
    let content = DemoContentRepository().loadOrFail()
    let plan = LearningPlanStore(
        storage: InMemoryPreferencesStore(preferences: .default, hasCompletedOnboarding: true),
        reminders: NoReminders()
    )
    AppRootView()
        .environment(SessionStore(content: content, haptics: NoOpFeedback()))
        .environment(TemplateSandboxStore(
            library: DemoContentRepository().loadTemplatesOrFail(words: content.words),
            words: content.words,
            haptics: NoOpFeedback(),
            speech: SilentSpeech()
        ))
        .environment(SpeechPlayer())
        .environment(AppSettingsStore(feedback: SettingsAwareFeedback(base: NoOpFeedback()), defaults: nil))
        .environment(plan)
        .environment(ProgressStore(defaults: nil))
        .environment(OnboardingStore(plan: plan, haptics: NoOpFeedback()))
}
