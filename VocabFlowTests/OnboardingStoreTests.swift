import XCTest
@testable import VocabFlow

@MainActor
final class OnboardingStoreTests: XCTestCase {
    private func makeStore(_ storage: InMemoryPreferencesStore = InMemoryPreferencesStore()) -> (OnboardingStore, LearningPlanStore) {
        let plan = LearningPlanStore(storage: storage, reminders: NoReminders())
        return (OnboardingStore(plan: plan, haptics: NoOpFeedback()), plan)
    }

    func testWalksForwardAndBack() async {
        let (store, _) = makeStore()
        XCTAssertEqual(store.step, .welcome)
        store.begin()
        XCTAssertEqual(store.step, .level)
        store.selectLevel(.b1)
        await store.continueToCollection()
        XCTAssertEqual(store.step, .collection)
        store.continueToTopics()
        XCTAssertEqual(store.step, .topics)
        store.continueToRoutine()
        XCTAssertEqual(store.step, .routine)
        store.back()
        XCTAssertEqual(store.step, .topics)
        store.back()
        XCTAssertEqual(store.step, .collection)
        store.back()
        XCTAssertEqual(store.step, .level)
        store.back()
        XCTAssertEqual(store.step, .welcome)
    }

    private func makeStore(api: StubVocabAPI) -> OnboardingStore {
        api.catalogCollections = [CatalogCollection(id: "c", slug: "c", title: "C", description: nil, topics: [])]
        return OnboardingStore(plan: LearningPlanStore(storage: InMemoryPreferencesStore(), reminders: NoReminders()), api: api, haptics: NoOpFeedback())
    }

    private let placed = PlacementResult(proficiencyLevel: .b1, correctCount: 9, totalCount: 18)

    func testAcceptingAPlacementDoesNotSaveTheLevelAgain() async {
        let api = StubVocabAPI()
        let store = makeStore(api: api)
        store.begin()
        store.openPlacementTest()
        XCTAssertEqual(store.step, .placement)
        await store.acceptPlacement(placed)
        XCTAssertEqual(store.step, .collection)
        XCTAssertEqual(store.level, .b1)
        XCTAssertEqual(api.levelUpdates, [])
    }

    func testBackFromCollectionSkipsThePlacementTest() async {
        let store = makeStore(api: StubVocabAPI())
        store.begin()
        store.openPlacementTest()
        await store.acceptPlacement(placed)
        store.back()
        XCTAssertEqual(store.step, .level)
    }

    func testStepChangesRememberTheirDirection() {
        let store = makeStore(api: StubVocabAPI())
        store.begin()
        XCTAssertFalse(store.isMovingBack)
        store.openPlacementTest()
        XCTAssertFalse(store.isMovingBack)
        store.back()
        XCTAssertTrue(store.isMovingBack)
        store.openPlacementTest()
        XCTAssertFalse(store.isMovingBack)
    }

    func testLeavingThePlacementTestReturnsToLevel() {
        let store = makeStore(api: StubVocabAPI())
        store.begin()
        store.openPlacementTest()
        store.back()
        XCTAssertEqual(store.step, .level)
    }

    func testDisagreeingWithAPlacementSavesOnlyTheNewLevel() async {
        let api = StubVocabAPI()
        let store = makeStore(api: api)
        store.begin()
        store.openPlacementTest()
        store.chooseLevelByHand(after: placed)
        XCTAssertEqual(store.step, .level)
        XCTAssertEqual(store.level, .b1)
        store.selectLevel(.c1)
        await store.continueToCollection()
        XCTAssertEqual(api.levelUpdates, [.c1])
    }

    func testReturningToThePlacedLevelSavesItAgain() async {
        let api = StubVocabAPI()
        let store = makeStore(api: api)
        store.begin()
        store.chooseLevelByHand(after: placed)
        store.selectLevel(.c1)
        await store.continueToCollection()
        store.back()
        store.selectLevel(.b1)
        await store.continueToCollection()
        XCTAssertEqual(api.levelUpdates, [.c1, .b1], "The server holds C1 by now")
    }

    func testChoosingALevelWithoutATestStillSavesIt() async {
        let api = StubVocabAPI()
        let store = makeStore(api: api)
        store.begin()
        store.selectLevel(.a2)
        await store.continueToCollection()
        XCTAssertEqual(api.levelUpdates, [.a2])
    }

    func testCannotLeaveLevelWithoutAChoice() async {
        let (store, _) = makeStore()
        store.begin()
        await store.continueToCollection()
        XCTAssertEqual(store.step, .level)
    }

    func testCannotLeaveTopicsWithoutASelection() async {
        let (store, _) = makeStore()
        store.begin()
        store.selectLevel(.a2)
        await store.continueToCollection()
        store.continueToTopics()
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
        preferences.wordsPerDay = 30
        preferences.adjustWordsPerDay(by: 1)
        XCTAssertEqual(preferences.wordsPerDay, 30)
    }

    func testEveryDayTogglesBetweenAllAndNone() {
        var preferences = LearningPreferences.default
        preferences.toggleEveryDay()
        XCTAssertTrue(preferences.isEveryDay)
        preferences.toggleEveryDay()
        XCTAssertTrue(preferences.learningDays.isEmpty)
        XCTAssertFalse(preferences.isComplete)
    }

    func testCreateFlowSavesThenFinishCompletes() async {
        let storage = InMemoryPreferencesStore()
        let (store, plan) = makeStore(storage)
        store.begin()
        store.selectLevel(.b2)
        await store.continueToCollection()
        store.continueToTopics()
        store.continueToRoutine()
        store.toggleDay(1)
        await store.createFlow()
        XCTAssertEqual(store.step, .ready)
        XCTAssertEqual(storage.preferences?.learningDays.contains(1), true)
        XCTAssertFalse(plan.hasCompletedOnboarding)

        store.finish()
        XCTAssertTrue(plan.hasCompletedOnboarding)
        XCTAssertTrue(storage.hasCompletedOnboarding)
    }

    func testCreateFlowRequiresALearningDay() async {
        let storage = InMemoryPreferencesStore()
        let (store, plan) = makeStore(storage)
        store.draft.learningDays = []
        await store.createFlow()
        XCTAssertNil(storage.preferences)
        XCTAssertNotEqual(store.step, .ready)
        store.finish()
        XCTAssertFalse(plan.hasCompletedOnboarding, "Finishing without a saved plan is ignored")
    }

    func testResumesFromSavedPreferences() {
        var saved = LearningPreferences.default
        saved.selectCollection("ielts")
        saved.toggleTopic("ielts-science")
        let (store, _) = makeStore(InMemoryPreferencesStore(preferences: saved))
        XCTAssertEqual(store.draft.collectionID, "ielts")
        XCTAssertEqual(store.draft.topicIDs, ["ielts-science"])
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

    func testSwitchingCollectionClearsTopics() {
        let (store, _) = makeStore()
        store.selectCollection("toeic")
        XCTAssertEqual(store.draft.collectionID, "toeic")
        XCTAssertTrue(store.draft.topicIDs.isEmpty)
        XCTAssertFalse(store.canContinueFromTopics)

        store.toggleTopic("toeic-office")
        store.selectCollection("toeic")
        XCTAssertEqual(store.draft.topicIDs, ["toeic-office"], "Re-selecting the same collection keeps topics")
    }

    func testUnknownCollectionIsIgnored() {
        var preferences = LearningPreferences.default
        preferences.selectCollection("klingon")
        XCTAssertEqual(preferences, .default)
    }

    func testTopicsOutsideTheCollectionAreIgnored() {
        var preferences = LearningPreferences.default
        preferences.toggleTopic("ielts-science")
        XCTAssertEqual(preferences.topicIDs, LearningPreferences.default.topicIDs)
    }

    func testSelectAllTogglesBetweenAllAndNone() {
        var preferences = LearningPreferences.default
        preferences.selectCollection("business")
        preferences.toggleAllTopics()
        XCTAssertEqual(preferences.topicIDs, TopicCatalog.collection(id: "business")?.topicIDs)
        XCTAssertTrue(preferences.hasAllTopics)
        preferences.toggleAllTopics()
        XCTAssertTrue(preferences.topicIDs.isEmpty)
    }

    func testTopicIDsAreUniqueAcrossCollections() {
        let ids = TopicCatalog.collections.flatMap(\.topics).map(\.id)
        XCTAssertEqual(ids.count, Set(ids).count)
    }

    func testDefaultTopicsExistInDefaultCollection() {
        let preferences = LearningPreferences.default
        XCTAssertNotNil(preferences.collection)
        XCTAssertTrue(preferences.topicIDs.isSubset(of: preferences.collection?.topicIDs ?? []))
    }

    func testRoundTripsThroughJSON() throws {
        var preferences = LearningPreferences.default
        preferences.selectCollection("ielts")
        preferences.toggleTopic("ielts-education")
        let data = try JSONEncoder().encode(preferences)
        XCTAssertEqual(try JSONDecoder().decode(LearningPreferences.self, from: data), preferences)
    }

    func testDecodesPlansSavedBeforeCollections() throws {
        let json = """
        {"topicIDs":["business","marketing","travel"],"wordsPerDay":8,"learningDays":[2],
         "reminderEnabled":false,"reminderHour":9,"reminderMinute":30}
        """
        let decoded = try JSONDecoder().decode(LearningPreferences.self, from: Data(json.utf8))
        XCTAssertEqual(decoded.collectionID, "everyday", "First collection holding a saved topic wins")
        XCTAssertEqual(decoded.topicIDs, ["travel"])
        XCTAssertEqual(decoded.wordsPerDay, 8)
    }
}
