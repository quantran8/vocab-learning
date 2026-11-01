import Foundation
import Observation

@Observable
@MainActor
final class OnboardingStore {
    enum Step: Int, CaseIterable {
        case welcome, level, collection, topics, routine, ready
    }

    private(set) var step: Step = .welcome
    var draft: LearningPreferences
    private(set) var level: CEFRLevel?
    /// A request is in flight; the step's action stays disabled until it answers.
    private(set) var isSaving = false
    private(set) var errorMessage: String?

    private let plan: LearningPlanStore
    private let api: VocabAPI
    let haptics: FeedbackProviding

    init(plan: LearningPlanStore, api: VocabAPI = OfflineVocabAPI(), haptics: FeedbackProviding) {
        self.plan = plan
        self.api = api
        self.haptics = haptics
        // Resume from the last saved choices if the learner quit before finishing.
        draft = plan.current
    }

    var canContinueFromCollection: Bool { draft.collection != nil }

    var canContinueFromTopics: Bool { !draft.topicIDs.isEmpty }

    // MARK: Navigation

    func begin() { step = .level }

    /// A new account may be finishing onboarding that a previous account left half done.
    func reset() {
        step = .welcome
        level = nil
        errorMessage = nil
        draft = plan.current
    }

    func back() {
        guard let previous = Step(rawValue: step.rawValue - 1) else { return }
        step = previous
    }

    /// Saves the level, then loads the catalog, which needs the account the level was saved on.
    func continueToCollection() async {
        guard let level else { return }
        await save {
            try await self.api.updateLevels(level)
            let catalog = try await self.api.catalog()
            guard !catalog.isEmpty else { throw APIError.invalidResponse }
            TopicCatalog.update(with: catalog)
            if self.draft.collection == nil, let first = TopicCatalog.collections.first {
                self.draft.collectionID = first.id
                self.draft.topicIDs = []
            }
            self.step = .collection
        }
    }

    func continueToTopics() {
        guard canContinueFromCollection else { return }
        step = .topics
    }

    func continueToRoutine() {
        guard canContinueFromTopics else { return }
        step = .routine
    }

    /// Sends the scope and daily goal, saves the choices and schedules reminders, then shows the summary.
    func createFlow() async {
        guard draft.isComplete else { return }
        let draft = draft
        await save {
            try await self.api.updateScope(LearningScope(collectionId: draft.collectionID, topicIds: Array(draft.topicIDs)))
            try await self.api.updateSettings(SettingsUpdate(dailyNewWordGoal: draft.wordsPerDay))
            self.plan.save(draft)
            self.haptics.success()
            self.step = .ready
        }
    }

    func finish() {
        plan.completeOnboarding()
    }

    private func save(_ work: @escaping () async throws -> Void) async {
        guard !isSaving else { return }
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }
        do {
            try await work()
        } catch {
            errorMessage = error.asAPIError.userMessage
        }
    }

    // MARK: Intents

    func selectLevel(_ level: CEFRLevel) {
        guard level != self.level else { return }
        self.level = level
        haptics.selectionChanged()
    }

    func selectCollection(_ id: String) {
        guard id != draft.collectionID else { return }
        draft.selectCollection(id)
        haptics.selectionChanged()
    }

    func toggleTopic(_ id: String) {
        draft.toggleTopic(id)
        haptics.selectionChanged()
    }

    func toggleAllTopics() {
        draft.toggleAllTopics()
        haptics.selectionChanged()
    }

    func toggleDay(_ weekday: Int) {
        draft.toggleDay(weekday)
        haptics.selectionChanged()
    }

    func toggleEveryDay() {
        draft.toggleEveryDay()
        haptics.selectionChanged()
    }

    func adjustWordsPerDay(by amount: Int) {
        let before = draft.wordsPerDay
        draft.adjustWordsPerDay(by: amount)
        if draft.wordsPerDay != before { haptics.selectionChanged() }
    }
}
