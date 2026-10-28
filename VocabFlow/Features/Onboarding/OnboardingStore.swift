import Foundation
import Observation

@Observable
@MainActor
final class OnboardingStore {
    enum Step: Int, CaseIterable {
        case welcome, topics, routine, ready
    }

    private(set) var step: Step = .welcome
    var draft: LearningPreferences
    var topics: TopicBrowserState

    private let plan: LearningPlanStore
    let haptics: FeedbackProviding

    init(plan: LearningPlanStore, haptics: FeedbackProviding) {
        self.plan = plan
        self.haptics = haptics
        // Resume from the last saved choices if the learner quit before finishing.
        let draft = plan.current
        self.draft = draft
        topics = TopicBrowserState(selected: draft.topicIDs)
    }

    var canContinueFromTopics: Bool { !draft.topicIDs.isEmpty }

    // MARK: Navigation

    func begin() { step = .topics }

    func back() {
        guard let previous = Step(rawValue: step.rawValue - 1) else { return }
        step = previous
    }

    func continueToRoutine() {
        guard canContinueFromTopics else { return }
        step = .routine
    }

    /// Saves the choices and schedules reminders, then shows the summary.
    func createFlow() {
        guard draft.isComplete else { return }
        plan.save(draft)
        haptics.success()
        step = .ready
    }

    func finish() {
        plan.completeOnboarding()
    }

    // MARK: Intents

    func toggleTopic(_ id: String) {
        draft.toggleTopic(id)
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
