import XCTest
@testable import VocabFlow

@MainActor
final class LearnerWordsTests: XCTestCase {
    private func makeStore(wordCount: Int) -> (LearnerStore, StubVocabAPI) {
        let api = StubVocabAPI()
        api.library = (0..<wordCount).map { PracticeFixtures.word("w\($0)", nextReviewAt: nil) }
        let plan = LearningPlanStore(storage: InMemoryPreferencesStore(), reminders: NoReminders())
        return (LearnerStore(api: api, plan: plan), api)
    }

    private func profile(level: CEFRLevel?) -> UserProfile {
        UserProfile(
            id: "u1",
            proficiencyLevel: level,
            learningLevel: level,
            settings: UserSettings(explanationLocale: "vi-VN", uiLocale: "vi-VN", timeZone: "UTC", dailyNewWordGoal: 5),
            scope: nil
        )
    }

    func testRefreshPicksUpALevelSavedDuringOnboarding() async {
        let (store, api) = makeStore(wordCount: 0)
        api.storedProfile = profile(level: nil)
        await store.load()
        XCTAssertNil(store.profile?.proficiencyLevel)

        api.storedProfile = profile(level: .b1)
        await store.refresh()
        XCTAssertEqual(store.profile?.proficiencyLevel, .b1)
    }

    func testAFailedRefreshKeepsTheProfile() async {
        let (store, api) = makeStore(wordCount: 0)
        api.storedProfile = profile(level: .a2)
        await store.load()

        api.storedProfile = nil
        await store.refresh()
        XCTAssertEqual(store.profile?.proficiencyLevel, .a2)
    }

    func testLoadsPagesUntilALibraryRunsOut() async {
        let (store, _) = makeStore(wordCount: LearnerStore.wordsPageSize + 3)

        await store.loadWords(matching: "")
        XCTAssertEqual(store.words.count, LearnerStore.wordsPageSize)
        XCTAssertTrue(store.hasMoreWords)

        await store.loadMoreWords()
        XCTAssertEqual(store.words.count, LearnerStore.wordsPageSize + 3)
        XCTAssertFalse(store.hasMoreWords)

        await store.loadMoreWords()
        XCTAssertEqual(store.words.count, LearnerStore.wordsPageSize + 3)
    }

    func testSearchReplacesTheListAndPagesWithinTheQuery() async {
        let (store, _) = makeStore(wordCount: LearnerStore.wordsPageSize + 3)
        await store.loadWords(matching: "")

        await store.loadWords(matching: "w1")
        XCTAssertEqual(store.wordsQuery, "w1")
        XCTAssertTrue(store.words.allSatisfy { $0.lemma.contains("w1") })
        XCTAssertFalse(store.hasMoreWords)
    }

    func testRepeatedWordAcrossPagesAppearsOnce() async {
        let (store, api) = makeStore(wordCount: LearnerStore.wordsPageSize)
        await store.loadWords(matching: "")

        api.library.insert(PracticeFixtures.word("new", nextReviewAt: nil), at: 0)
        await store.loadMoreWords()
        XCTAssertEqual(Set(store.words.map(\.id)).count, store.words.count)
        XCTAssertEqual(store.words.count, LearnerStore.wordsPageSize)
    }

    func testFailedPageKeepsTheListAndCanRetry() async {
        let (store, api) = makeStore(wordCount: LearnerStore.wordsPageSize + 1)
        await store.loadWords(matching: "")

        api.wordsError = .transport
        await store.loadMoreWords()
        XCTAssertEqual(store.words.count, LearnerStore.wordsPageSize)
        XCTAssertNotNil(store.wordsError)
        XCTAssertTrue(store.hasMoreWords)

        api.wordsError = nil
        await store.loadMoreWords()
        XCTAssertEqual(store.words.count, LearnerStore.wordsPageSize + 1)
        XCTAssertNil(store.wordsError)
    }

    func testFailedNewSearchClearsTheOldRows() async {
        let (store, api) = makeStore(wordCount: LearnerStore.wordsPageSize + 1)
        await store.loadWords(matching: "")

        api.wordsError = .transport
        await store.loadWords(matching: "w1")
        XCTAssertTrue(store.words.isEmpty)
        XCTAssertFalse(store.hasMoreWords)
        XCTAssertNotNil(store.wordsError)
    }

    func testAnswerForAnOlderQueryIsIgnored() async {
        let (store, api) = makeStore(wordCount: 3)
        let (started, startedContinuation) = AsyncStream<Void>.makeStream()
        let (release, releaseContinuation) = AsyncStream<Void>.makeStream()
        api.onWords = {
            startedContinuation.yield()
            for await _ in release { break }
        }

        let older = Task { await store.loadWords(matching: "w1") }
        for await _ in started { break }
        api.onWords = nil
        await store.loadWords(matching: "w2")
        releaseContinuation.finish()
        await older.value

        XCTAssertEqual(store.wordsQuery, "w2")
        XCTAssertEqual(store.words.map(\.lemma), ["w2"])
        XCTAssertFalse(store.isSearchingWords)
    }

    func testRefreshLoadsStatsAndFirstPage() async {
        let (store, _) = makeStore(wordCount: LearnerStore.wordsPageSize + 1)
        await store.refresh()
        XCTAssertEqual(store.wordStats?.learnedWords, LearnerStore.wordsPageSize + 1)
        XCTAssertEqual(store.words.count, LearnerStore.wordsPageSize)
    }
}
