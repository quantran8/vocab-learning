import SwiftUI

@main
struct VocabFlowApp: App {
    @State private var store: SessionStore
    @State private var sandbox: TemplateSandboxStore
    @State private var speech: SpeechPlayer
    @State private var settings: AppSettingsStore
    @State private var plan: LearningPlanStore
    @State private var progress: ProgressStore
    @State private var onboarding: OnboardingStore
    @State private var auth: AuthStore
    @State private var learner: LearnerStore
    @State private var practice: PracticeSessionStore
    @State private var customWords: CustomWordStore

    init() {
        let repository = DemoContentRepository()
        let content = repository.loadOrFail()
        let settings = AppSettingsStore(feedback: SettingsAwareFeedback(base: FeedbackHaptics()))
        let haptics = settings.feedback
        let speech = SpeechPlayer()
        let plan = LearningPlanStore(storage: UserDefaultsPreferencesStore(), reminders: NotificationReminderScheduler())
        let progress = ProgressStore()
        let client = APIClient(baseURL: APIConfiguration.baseURL, tokens: KeychainTokenStore())
        let api = LiveVocabAPI(client: client)
        let auth = AuthStore(api: api)
        let learner = LearnerStore(api: api, plan: plan)
        let practice = PracticeSessionStore(api: api, audio: AudioClipPlayer(), recorder: VoiceRecorder(), haptics: haptics)
        let onboarding = OnboardingStore(plan: plan, api: api, haptics: haptics)
        let customWords = CustomWordStore(api: api, audio: AudioClipPlayer())
        customWords.onRoadmapChanged = { [learner] in await learner.refresh() }
        auth.onSignedOut = { [learner, practice, onboarding, customWords] in
            practice.close()
            learner.reset()
            onboarding.reset()
            customWords.reset()
        }
        Task { [auth] in
            await client.setSessionEndedHandler { auth.sessionEnded() }
        }
        let store = SessionStore(content: content, haptics: haptics)
        store.onFinish = { [progress, unowned store] in
            progress.recordFinishedRun(words: content.words, result: store.result)
        }

        _settings = State(initialValue: settings)
        _speech = State(initialValue: speech)
        _plan = State(initialValue: plan)
        _progress = State(initialValue: progress)
        _onboarding = State(initialValue: onboarding)
        _auth = State(initialValue: auth)
        _learner = State(initialValue: learner)
        _practice = State(initialValue: practice)
        _customWords = State(initialValue: customWords)
        _store = State(initialValue: store)
        _sandbox = State(initialValue: TemplateSandboxStore(
            templates: repository.loadLabOrFail().templates,
            session: PracticeSessionStore(api: OfflineVocabAPI(), audio: AudioClipPlayer(), recorder: VoiceRecorder(), haptics: haptics)
        ))
    }

    var body: some Scene {
        WindowGroup {
            AppRootView()
                .scrollIndicators(.hidden)
                .environment(store)
                .environment(sandbox)
                .environment(speech)
                .environment(settings)
                .environment(plan)
                .environment(progress)
                .environment(onboarding)
                .environment(auth)
                .environment(learner)
                .environment(practice)
                .environment(customWords)
        }
    }
}
