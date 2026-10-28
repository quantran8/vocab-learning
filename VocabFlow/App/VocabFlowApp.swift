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

    init() {
        let repository = DemoContentRepository()
        let content = repository.loadOrFail()
        let settings = AppSettingsStore(feedback: SettingsAwareFeedback(base: FeedbackHaptics()))
        let haptics = settings.feedback
        let speech = SpeechPlayer()
        let plan = LearningPlanStore(storage: UserDefaultsPreferencesStore(), reminders: NotificationReminderScheduler())
        let progress = ProgressStore()
        let store = SessionStore(content: content, haptics: haptics)
        store.onFinish = { [progress, unowned store] in
            progress.recordFinishedRun(words: content.words, result: store.result)
        }

        _settings = State(initialValue: settings)
        _speech = State(initialValue: speech)
        _plan = State(initialValue: plan)
        _progress = State(initialValue: progress)
        _onboarding = State(initialValue: OnboardingStore(plan: plan, haptics: haptics))
        _store = State(initialValue: store)
        _sandbox = State(initialValue: TemplateSandboxStore(
            library: repository.loadTemplatesOrFail(words: content.words),
            words: content.words,
            haptics: haptics,
            speech: speech
        ))
    }

    var body: some Scene {
        WindowGroup {
            AppRootView()
                .environment(store)
                .environment(sandbox)
                .environment(speech)
                .environment(settings)
                .environment(plan)
                .environment(progress)
                .environment(onboarding)
        }
    }
}
