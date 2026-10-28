import XCTest
@testable import VocabFlow

@MainActor
final class OnboardingStoreTests: XCTestCase {
    private func makeStore(_ storage: InMemoryPreferencesStore = InMemoryPreferencesStore()) -> (OnboardingStore, LearningPlanStore) {
        let plan = LearningPlanStore(storage: storage, reminders: NoReminders())
        return (OnboardingStore(plan: plan, haptics: NoOpFeedback()), plan)
    }

    func testWalksForwardAndBack() {
        let (store, _) = makeStore()
        XCTAssertEqual(store.step, .welcome)
        store.begin()
        XCTAssertEqual(store.step, .topics)
        store.continueToRoutine()
        XCTAssertEqual(store.step, .routine)
        store.back()
        XCTAssertEqual(store.step, .topics)
        store.back()
        store.back()
        XCTAssertEqual(store.step, .welcome)
    }

    func testCannotLeaveTopicsWithoutASelection() {
        let (store, _) = makeStore()
        store.begin()
        for id in store.draft.topicIDs { store.toggleTopic(id) }
        XCTAssertFalse(store.canContinueFromTopics)
        store.continueToRoutine()
        XCTAssertEqual(store.step, .topics)
    }

    func testWordsPerDayIsClamped() {
        var preferences = LearningPreferences.default
        preferences.wordsPerDay = 1
        preferences.adjustWordsPerDay(by: -1)
        XCTAssertEqual(preferences.wordsPerDay, 1)
        preferences.wordsPerDay = 50
        preferences.adjustWordsPerDay(by: 1)
        XCTAssertEqual(preferences.wordsPerDay, 50)
    }

    func testEveryDayTogglesBetweenAllAndNone() {
        var preferences = LearningPreferences.default
        preferences.toggleEveryDay()
        XCTAssertTrue(preferences.isEveryDay)
        preferences.toggleEveryDay()
        XCTAssertTrue(preferences.learningDays.isEmpty)
        XCTAssertFalse(preferences.isComplete)
    }

    func testCreateFlowSavesThenFinishCompletes() {
        let storage = InMemoryPreferencesStore()
        let (store, plan) = makeStore(storage)
        store.begin()
        store.continueToRoutine()
        store.toggleDay(1)
        store.createFlow()
        XCTAssertEqual(store.step, .ready)
        XCTAssertEqual(storage.preferences?.learningDays.contains(1), true)
        XCTAssertFalse(plan.hasCompletedOnboarding)

        store.finish()
        XCTAssertTrue(plan.hasCompletedOnboarding)
        XCTAssertTrue(storage.hasCompletedOnboarding)
    }

    func testCreateFlowRequiresALearningDay() {
        let storage = InMemoryPreferencesStore()
        let (store, plan) = makeStore(storage)
        store.draft.learningDays = []
        store.createFlow()
        XCTAssertNil(storage.preferences)
        XCTAssertNotEqual(store.step, .ready)
        store.finish()
        XCTAssertFalse(plan.hasCompletedOnboarding, "Finishing without a saved plan is ignored")
    }

    func testResumesFromSavedPreferences() {
        var saved = LearningPreferences.default
        saved.topicIDs = ["travel"]
        let (store, _) = makeStore(InMemoryPreferencesStore(preferences: saved))
        XCTAssertEqual(store.draft.topicIDs, ["travel"])
    }

    func testPlanIgnoresIncompleteSaves() {
        let storage = InMemoryPreferencesStore(preferences: .default)
        let plan = LearningPlanStore(storage: storage, reminders: NoReminders())
        var broken = LearningPreferences.default
        broken.topicIDs = []
        plan.save(broken)
        XCTAssertEqual(plan.current, .default)
        XCTAssertEqual(storage.preferences, .default)
    }

    func testSearchMatchesTopicOrGroupName() {
        let byTopic = TopicCatalog.filtered(by: "trav")
        XCTAssertEqual(byTopic.flatMap(\.topics).map(\.id), ["travel"])

        let byGroup = TopicCatalog.filtered(by: "career")
        XCTAssertEqual(byGroup.map(\.id), ["work-career"])
        XCTAssertEqual(byGroup.first?.topics.count, 6)

        XCTAssertTrue(TopicCatalog.filtered(by: "zzz").isEmpty)
        XCTAssertEqual(TopicCatalog.filtered(by: "  ").count, TopicCatalog.groups.count)
    }

    func testGroupsStartFoldedExceptFirstAndThoseWithPicks() {
        let browser = TopicBrowserState(selected: LearningPreferences.default.topicIDs)
        let groups = TopicCatalog.groups
        XCTAssertTrue(browser.isExpanded(groups[0]))
        XCTAssertTrue(browser.isExpanded(groups[1]), "Work & career holds the default Business pick")
        XCTAssertFalse(browser.isExpanded(groups[2]))
    }

    func testToggleGroupAndSearchAlwaysExpands() {
        var browser = TopicBrowserState(selected: [])
        let study = TopicCatalog.groups[2]
        browser.toggleGroup(study.id)
        XCTAssertTrue(browser.isExpanded(study))
        browser.toggleGroup(study.id)
        XCTAssertFalse(browser.isExpanded(study))

        browser.query = "science"
        XCTAssertTrue(browser.isExpanded(study))
        browser.toggleGroup(study.id)
        browser.query = ""
        XCTAssertFalse(browser.isExpanded(study), "Toggling is ignored while searching")
    }

    func testDefaultTopicsExistInCatalog() {
        let ids = Set(TopicCatalog.groups.flatMap(\.topics).map(\.id))
        XCTAssertTrue(LearningPreferences.default.topicIDs.isSubset(of: ids))
    }
}
