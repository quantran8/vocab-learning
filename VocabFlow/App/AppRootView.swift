import SwiftUI

struct AppRootView: View {
    @Environment(SessionStore.self) private var store
    @Environment(TemplateSandboxStore.self) private var sandbox
    @Environment(LearningPlanStore.self) private var plan
    @Environment(AppSettingsStore.self) private var settings
    @Environment(AuthStore.self) private var auth
    @Environment(LearnerStore.self) private var learner
    @Environment(PracticeSessionStore.self) private var practice
    @Environment(ChallengeRunStore.self) private var challengeRun
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shellTab: MainTab = .home
    @State private var profilePath: [ShellPage] = []
    /// Kept across the route swap, so a session or challenge started from the Challenge Map returns to it.
    @State private var homePath: [ShellPage] = []
    /// Set once the splash has been up for `MotionTokens.splashHold`.
    @State private var splashHeld = false
    /// Set once the splash is gone; it doesn't come back for the rest of the launch.
    @State private var launched = false

    var body: some View {
        let motion = MotionCoordinator(reduceMotion: reduceMotion || settings.reduceMotion)
        ZStack {
            Color.canvas.ignoresSafeArea()
            screen
                .id(route)
                .transition(motion.routeTransition)
                // Strings built with `String(localized:)` only update when their view is rebuilt.
                .id(settings.language)
        }
        .environment(\.motion, motion)
        .environment(\.locale, settings.language?.locale ?? .autoupdatingCurrent)
        .scrollBounceBehavior(.basedOnSize)
        .preferredColorScheme(.light)
        .task { await auth.restore() }
        .task {
            try? await Task.sleep(for: .seconds(MotionTokens.splashHold))
            splashHeld = true
            endSplashIfReady(motion)
        }
        .onChange(of: isLaunchLoading) { _, _ in endSplashIfReady(motion) }
        // Waits for the language step, so `load()` sends the chosen `uiLocale` before anything reads the catalog.
        .task(id: canLoadLearner) {
            if canLoadLearner { await learner.load() }
        }
        .task(id: auth.phase) {
            // The next account starts on Home.
            if auth.phase == .signedOut {
                shellTab = .home
                profilePath = []
                homePath = []
            }
        }
    }

    /// The account is still loading, which would otherwise show the loading screen.
    private var isLaunchLoading: Bool {
        auth.phase == .launching || (canLoadLearner && learner.phase == .loading)
    }

    private func endSplashIfReady(_ motion: MotionCoordinator) {
        guard !launched, splashHeld, !isLaunchLoading else { return }
        motion.perform(MotionTokens.transition) { launched = true }
    }

    private var canLoadLearner: Bool {
        auth.phase == .signedIn && settings.language != nil
    }

    private var route: RouteID {
        launched ? appRoute : .splash
    }

    private var appRoute: RouteID {
        guard auth.phase == .signedIn else {
            return auth.phase == .launching ? .loading : .auth
        }
        guard settings.language != nil else {
            return .language
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
        // Before the Lab: the Lab's Match Madness rounds run here too, and closing one returns to the Lab.
        if challengeRun.isActive {
            return .challenge(token: challengeRun.runToken)
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
        if !launched {
            SplashView()
        } else if auth.phase == .launching {
            StatusScreen(title: "Syll", isBusy: true)
        } else if auth.phase == .signedOut {
            AuthView()
        } else if settings.language == nil {
            LanguageSelectionView()
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
            StatusScreen(title: "Syll", isBusy: true)
        } else if !plan.hasCompletedOnboarding {
            OnboardingView()
        } else if practice.isActive {
            PracticeSessionView()
        } else if challengeRun.isActive {
            MatchMadnessGameView()
        } else if sandbox.isOpen {
            if sandbox.activeTemplate != nil {
                LabTaskView()
            } else {
                PracticeLabView()
            }
        } else {
            switch store.state.phase {
            case .home: MainShellView(tab: $shellTab, homePath: $homePath, profilePath: $profilePath)
            case .learn, .build, .recall: SessionFlowView()
            case .results: ResultsView()
            }
        }
    }
}

private enum RouteID: Hashable {
    case splash
    case loading
    case auth
    case language
    case onboarding
    case practice(token: UUID)
    case challenge(token: UUID)
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
        .environment(PlacementTestStore(api: OfflineVocabAPI(), haptics: NoOpFeedback()))
        .environment(ChallengeMapStore(api: OfflineVocabAPI()))
        .environment(RankingStore(api: OfflineVocabAPI()))
        .environment(ChallengeRunStore(api: OfflineVocabAPI(), haptics: NoOpFeedback(), defaults: nil))
}
