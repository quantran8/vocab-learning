import SwiftUI

struct AppRootView: View {
    @Environment(SessionStore.self) private var store
    @Environment(TemplateSandboxStore.self) private var sandbox
    @Environment(LearningPlanStore.self) private var plan
    @Environment(AppSettingsStore.self) private var settings
    @Environment(AuthStore.self) private var auth
    @Environment(LearnerStore.self) private var learner
    @Environment(PracticeSessionStore.self) private var practice
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let motion = MotionCoordinator(reduceMotion: reduceMotion || settings.reduceMotion)
        ZStack {
            Color.canvas.ignoresSafeArea()
            screen
                .id(route)
                .transition(motion.routeTransition)
                .environment(\.designZone, zone)
        }
        .environment(\.motion, motion)
        .scrollBounceBehavior(.basedOnSize)
        .preferredColorScheme(.light)
        .task { await auth.restore() }
        .task(id: auth.phase) {
            if auth.phase == .signedIn { await learner.load() }
        }
    }

    private var zone: DesignZone {
        switch route {
        case .practice, .flow, .results: .lesson
        case .lab(let template): template == nil ? .product : .lesson
        case .loading, .auth, .onboarding, .home: .product
        }
    }

    private var route: RouteID {
        guard auth.phase == .signedIn else {
            return auth.phase == .launching ? .loading : .auth
        }
        guard learner.phase == .ready else {
            return .loading
        }
        if !plan.hasCompletedOnboarding {
            return .onboarding
        }
        if practice.isActive {
            return .practice(token: practice.sessionToken)
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
        if auth.phase == .launching {
            StatusScreen(title: "Vocab Flow", isBusy: true)
        } else if auth.phase == .signedOut {
            AuthView()
        } else if case .failed(let message) = learner.phase {
            StatusScreen(title: "Couldn’t load your account", message: Text(verbatim: message)) {
                PrimaryButton(title: "Try again") {
                    Task { await learner.load() }
                }
                SecondaryButton(title: "Log out") {
                    Task { await auth.signOut() }
                }
            }
        } else if learner.phase == .loading {
            StatusScreen(title: "Vocab Flow", isBusy: true)
        } else if !plan.hasCompletedOnboarding {
            OnboardingView()
        } else if practice.isActive {
            PracticeSessionView()
        } else if sandbox.isOpen {
            if sandbox.activeTemplate != nil {
                LabTaskView()
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
    case loading
    case auth
    case onboarding
    case practice(token: UUID)
    case home(token: UUID)
    case flow(token: UUID)
    case results(token: UUID)
    case lab(template: TaskTemplate?)
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
            templates: DemoContentRepository().loadLabOrFail().templates,
            session: PracticeSessionStore(api: OfflineVocabAPI(), audio: SilentAudioClips(), recorder: NoVoiceRecorder(), haptics: NoOpFeedback(), transcriber: NoSpeechTranscriber())
        ))
        .environment(SpeechPlayer())
        .environment(AppSettingsStore(feedback: SettingsAwareFeedback(base: NoOpFeedback()), defaults: nil))
        .environment(plan)
        .environment(ProgressStore(defaults: nil))
        .environment(OnboardingStore(plan: plan, haptics: NoOpFeedback()))
        .environment(AuthStore(api: OfflineVocabAPI()))
        .environment(LearnerStore(api: OfflineVocabAPI(), plan: plan))
        .environment(PracticeSessionStore(
            api: OfflineVocabAPI(),
            audio: SilentAudioClips(),
            recorder: NoVoiceRecorder(),
            haptics: NoOpFeedback(),
            transcriber: NoSpeechTranscriber()
        ))
        .environment(CustomWordStore(api: OfflineVocabAPI(), audio: SilentAudioClips()))
}
