import XCTest
@testable import VocabFlow

@MainActor
final class ChallengeRunStoreTests: XCTestCase {
    private var api: StubVocabAPI!
    private var clockOrigin = ContinuousClock.now
    private var offset: Duration = .zero
    private var defaults: UserDefaults!
    private let node = ChallengeNodeRef(chapterNo: 1, levelNo: 2)

    override func setUp() {
        super.setUp()
        api = StubVocabAPI()
        clockOrigin = ContinuousClock.now
        offset = .zero
        defaults = UserDefaults(suiteName: "ChallengeRunStoreTests-\(UUID().uuidString)")
    }

    private func makeStore() -> ChallengeRunStore {
        ChallengeRunStore(
            api: api,
            haptics: NoOpFeedback(),
            now: { [unowned self] in self.clockOrigin.advanced(by: self.offset) },
            tickInterval: nil,
            defaults: defaults
        )
    }

    private func plan(goal: Int = 2, visible: Int = 2) -> ChallengeRunPlan {
        var plan = ChallengeRunPlan.sandbox(visiblePairs: visible, goalMatches: goal)
        plan = ChallengeRunPlan(
            runId: "run-1", gameMode: plan.gameMode, chapterNo: node.chapterNo, levelNo: node.levelNo, policyVersion: "v1",
            explanationLocale: "vi-VN", goalMatches: goal, visiblePairs: visible, timeLimitMs: 90_000,
            minMatchesBetweenRepeats: 3, starCriteria: plan.starCriteria, boardSeed: plan.boardSeed, pairs: plan.pairs
        )
        return plan
    }

    /// A commit response as the backend sends it (`FRONTEND_FLOW.md` §12.4).
    private func result(stars: Int = 2, outcome: String = "cleared", next: ChallengeNodeRef? = nil) throws -> ChallengeCommitResponse {
        let unlock: [String: Any] = next.map { ["kind": "level", "chapterNo": $0.chapterNo, "levelNo": $0.levelNo] } ?? ["kind": "none"]
        let json: [String: Any] = [
            "runId": "run-1", "status": "committed",
            "result": [
                "outcome": outcome, "starsThisRun": stars, "bestStars": stars, "correctMatches": 2, "mistakes": 0,
                "longestCombo": 2, "elapsedMs": 4000, "score": 210, "bestScore": 210,
            ],
            "unlock": unlock,
            "nextAction": next == nil ? "open_map" : "play_next_level",
        ]
        return try JSONDecoder().decode(ChallengeCommitResponse.self, from: JSONSerialization.data(withJSONObject: json))
    }

    /// One wrong pair, then both pairs, at 1, 2 and 3 seconds after `offset`'s current value.
    private func playToGoal(_ store: ChallengeRunStore) {
        let start = offset
        offset = start + .seconds(1)
        store.tapWord("w1")
        store.tapMeaning("m2")   // wrong
        offset = start + .seconds(2)
        store.tapMeaning("m1")
        store.tapWord("w1")
        offset = start + .seconds(3)
        store.tapWord("w2")
        store.tapMeaning("m2")
    }

    // MARK: Issue → start → play → commit

    func testFullRunIssuesStartsPlaysAndCommits() async throws {
        api.issueResults = [.success(plan())]
        api.challengeCommitResults = [.success(try result(next: ChallengeNodeRef(chapterNo: 1, levelNo: 3)))]
        let store = makeStore()
        var settled = 0
        store.onSettled = { settled += 1 }

        await store.play(node, level: nil)
        XCTAssertEqual(store.stage, .ready)
        XCTAssertEqual(api.issuedRuns, [node])
        XCTAssertTrue(api.startedRuns.isEmpty, "The clock and the run start only on Start")

        offset = .seconds(30)   // time on the ready screen doesn't count
        await store.begin()
        XCTAssertEqual(store.stage, .playing)
        XCTAssertEqual(api.startedRuns, ["run-1"])

        playToGoal(store)
        XCTAssertEqual(store.stage, .committing)
        await store.settleTask?.value

        guard case .results(let outcome) = store.stage else { return XCTFail("Expected results, got \(store.stage)") }
        XCTAssertEqual(outcome.nextNode, ChallengeNodeRef(chapterNo: 1, levelNo: 3))
        XCTAssertTrue(outcome.isFirstClear)
        XCTAssertEqual(settled, 1)
        XCTAssertFalse(store.hasPendingRun)

        let body = try XCTUnwrap(api.challengeCommitBodies.first)
        let decoded = try JSONDecoder().decode(ChallengeCommitBody.self, from: body)
        XCTAssertEqual(decoded.endedReason, .goalReached)
        XCTAssertEqual(decoded.endedElapsedMs, 3000)
        XCTAssertEqual(decoded.events.map(\.elapsedMs), [1000, 2000, 3000])
        XCTAssertEqual(decoded.events.map(\.seq), [1, 2, 3])
    }

    func testFailedCommitRetriesWithIdenticalBytes() async throws {
        api.issueResults = [.success(plan())]
        api.challengeCommitResults = [.failure(.transport), .success(try result())]
        let store = makeStore()
        await store.play(node, level: nil)
        await store.begin()
        playToGoal(store)
        await store.settleTask?.value
        guard case .commitFailed = store.stage else { return XCTFail("Expected commitFailed, got \(store.stage)") }
        XCTAssertTrue(store.hasPendingRun, "The frozen body survives a relaunch")

        offset = .seconds(80)   // the clock moving on changes nothing in the body
        await store.retryCommit()
        XCTAssertEqual(api.challengeCommitBodies.count, 2)
        XCTAssertEqual(api.challengeCommitBodies[0], api.challengeCommitBodies[1])
        guard case .results = store.stage else { return XCTFail("Expected results") }
    }

    func testCommitConflictRendersTheStoredResult() async throws {
        api.issueResults = [.success(plan())]
        api.challengeCommitResults = [.failure(.server(status: 409, code: ChallengeErrorCode.commitConflict, message: "", retryable: false, requestID: nil))]
        api.runStatus = .success(ChallengeRunStatus(runId: "run-1", status: .committed, response: try result(stars: 3)))
        let store = makeStore()
        await store.play(node, level: nil)
        await store.begin()
        playToGoal(store)
        await store.settleTask?.value
        guard case .results(let outcome) = store.stage else { return XCTFail("Expected results, got \(store.stage)") }
        XCTAssertEqual(outcome.result.starsThisRun, 3)
        XCTAssertEqual(api.statusRequests, ["run-1"])
    }

    func testTimeUpEndsTheRunEvenAfterTheBackground() async throws {
        api.issueResults = [.success(plan())]
        api.challengeCommitResults = [.success(try result(stars: 0, outcome: "failed"))]
        let store = makeStore()
        await store.play(node, level: nil)
        await store.begin()
        store.tapWord("w1")
        store.tapMeaning("m1")

        // Backgrounded for two minutes: nothing ticked, the clock kept running.
        offset = .seconds(120)
        store.tapWord("w2")
        XCTAssertEqual(store.stage, .committing, "A tap after time is up ends the run instead of counting")
        await store.settleTask?.value

        let body = try JSONDecoder().decode(ChallengeCommitBody.self, from: XCTUnwrap(api.challengeCommitBodies.first))
        XCTAssertEqual(body.endedReason, .timeUp)
        XCTAssertEqual(body.endedElapsedMs, 90_000)
        XCTAssertEqual(body.events.count, 1)
        guard case .results(let outcome) = store.stage else { return XCTFail("Expected results") }
        XCTAssertFalse(outcome.isCleared)
    }

    func testTickAtTheLimitEndsAsTimeUp() async throws {
        api.issueResults = [.success(plan())]
        api.challengeCommitResults = [.success(try result(stars: 0, outcome: "failed"))]
        let store = makeStore()
        await store.play(node, level: nil)
        await store.begin()
        offset = .milliseconds(89_999)
        store.tick()
        XCTAssertEqual(store.stage, .playing)
        offset = .milliseconds(90_000)
        store.tick()
        XCTAssertEqual(store.stage, .committing)
        await store.settleTask?.value
    }

    func testQuitWhilePlayingCommitsQuitAndCloses() async throws {
        api.issueResults = [.success(plan())]
        api.challengeCommitResults = [.success(try result(stars: 0, outcome: "quit"))]
        let store = makeStore()
        await store.play(node, level: nil)
        await store.begin()
        offset = .seconds(5)
        await store.quit()
        XCTAssertEqual(store.stage, .idle)
        let body = try JSONDecoder().decode(ChallengeCommitBody.self, from: XCTUnwrap(api.challengeCommitBodies.first))
        XCTAssertEqual(body.endedReason, .quit)
        XCTAssertEqual(body.endedElapsedMs, 5000)
    }

    func testLeavingBeforeStartCancelsTheIssuedRun() async {
        api.issueResults = [.success(plan())]
        let store = makeStore()
        await store.play(node, level: nil)
        await store.leave()
        XCTAssertEqual(store.stage, .idle)
        XCTAssertEqual(api.quitRuns, ["run-1"])
        XCTAssertFalse(store.hasPendingRun)
    }

    func testExpiredStartShowsExpired() async {
        api.issueResults = [.success(plan())]
        api.startResults = [.failure(.server(status: 410, code: ChallengeErrorCode.runExpired, message: "", retryable: false, requestID: nil))]
        let store = makeStore()
        await store.play(node, level: nil)
        await store.begin()
        XCTAssertEqual(store.stage, .failed(.expired))
    }

    func testTransportFailureOnStartStaysReady() async {
        api.issueResults = [.success(plan())]
        api.startResults = [.failure(.transport)]
        let store = makeStore()
        await store.play(node, level: nil)
        await store.begin()
        XCTAssertEqual(store.stage, .ready)
        XCTAssertNotNil(store.startError)
    }

    func testIssueErrorsMapToTheirScreens() async {
        let store = makeStore()
        api.issueResults = [.failure(.server(status: 409, code: ChallengeErrorCode.runActive, message: "", retryable: false, requestID: nil))]
        await store.play(node, level: nil)
        XCTAssertEqual(store.stage, .runActive(runID: nil))

        api.issueResults = [.failure(.server(status: 403, code: ChallengeErrorCode.levelLocked, message: "", retryable: false, requestID: nil))]
        await store.play(node, level: nil)
        XCTAssertEqual(store.stage, .failed(.levelLocked))

        api.issueResults = [.failure(.server(status: 422, code: ChallengeErrorCode.notEnoughVocabulary, message: "", retryable: false, requestID: nil))]
        await store.play(node, level: nil)
        XCTAssertEqual(store.stage, .failed(.notEnoughVocabulary))

        api.issueResults = [.failure(.server(status: 422, code: ChallengeErrorCode.contentUnavailable, message: "", retryable: false, requestID: nil))]
        await store.play(node, level: nil)
        guard case .failed(.contentUnavailable) = store.stage else { return XCTFail("Expected contentUnavailable") }
    }

    func testRecoveryCommitsAFrozenBodyLeftByAKilledApp() async throws {
        api.issueResults = [.success(plan())]
        api.challengeCommitResults = [.failure(.transport)]
        let first = makeStore()
        await first.play(node, level: nil)
        await first.begin()
        playToGoal(first)
        await first.settleTask?.value
        let frozen = try XCTUnwrap(api.challengeCommitBodies.first)

        // Relaunch.
        api.runStatus = .success(ChallengeRunStatus(runId: "run-1", status: .started, response: nil))
        api.challengeCommitResults = [.success(try result())]
        let second = makeStore()
        XCTAssertTrue(second.hasPendingRun)
        await second.recoverPendingRun()
        XCTAssertEqual(api.challengeCommitBodies.last, frozen)
        XCTAssertFalse(second.hasPendingRun)
        XCTAssertEqual(second.stage, .idle, "Recovery is silent; the map refresh shows the outcome")
    }

    func testRecoverySettlesAStartedRunWithoutEventsAsQuit() async {
        api.issueResults = [.success(plan())]
        let first = makeStore()
        await first.play(node, level: nil)
        await first.begin()
        // Killed mid-run: no body was frozen.

        api.runStatus = .success(ChallengeRunStatus(runId: "run-1", status: .started, response: nil))
        let second = makeStore()
        await second.recoverPendingRun()
        XCTAssertEqual(api.quitRuns, ["run-1"])
        XCTAssertTrue(api.challengeCommitBodies.isEmpty, "Never commits a reconstructed run")
        XCTAssertFalse(second.hasPendingRun)
    }

    func testSandboxRoundEndsLocallyAndUntimedNeverTimesOut() async {
        let store = makeStore()
        store.startSandbox(plan: plan(), timed: false)
        await store.begin()
        offset = .seconds(600)
        store.tick()
        XCTAssertEqual(store.stage, .playing)
        playToGoal(store)
        guard case .sandboxResults(let summary) = store.stage else { return XCTFail("Expected sandbox results") }
        XCTAssertTrue(summary.reachedGoal)
        XCTAssertEqual(summary.mistakes, 1)
        XCTAssertTrue(api.issuedRuns.isEmpty)
        XCTAssertTrue(api.startedRuns.isEmpty)
        XCTAssertTrue(api.challengeCommitBodies.isEmpty)
    }

    func testRunActiveOverAnIssuedRunDropsItAndIssuesAgain() async {
        api.issueResults = [
            .failure(.server(status: 409, code: ChallengeErrorCode.runActive, message: "", retryable: false, requestID: nil, details: ["runId": "old-run"])),
            .success(plan()),
        ]
        api.runStatus = .success(ChallengeRunStatus(runId: "old-run", status: .issued, response: nil))
        let store = makeStore()
        await store.play(node, level: nil)
        XCTAssertEqual(api.quitRuns, ["old-run"])
        XCTAssertEqual(store.stage, .ready)
        XCTAssertEqual(store.plan?.runId, "run-1")
    }

    func testRunActiveOverAStartedRunAsksTheLearner() async {
        api.issueResults = [.failure(.server(status: 409, code: ChallengeErrorCode.runActive, message: "", retryable: false, requestID: nil, details: ["runId": "old-run"]))]
        api.runStatus = .success(ChallengeRunStatus(runId: "old-run", status: .started, response: nil))
        let store = makeStore()
        await store.play(node, level: nil)
        XCTAssertEqual(store.stage, .runActive(runID: "old-run"))
        XCTAssertTrue(api.quitRuns.isEmpty)
    }

    func testQuitAtTheDeadlineIsSentAsTimeUp() async throws {
        api.issueResults = [.success(plan())]
        api.challengeCommitResults = [.success(try result(stars: 0, outcome: "failed"))]
        let store = makeStore()
        await store.play(node, level: nil)
        await store.begin()
        offset = .seconds(95)
        await store.quit()
        let body = try JSONDecoder().decode(ChallengeCommitBody.self, from: XCTUnwrap(api.challengeCommitBodies.first))
        XCTAssertEqual(body.endedReason, .timeUp)
        XCTAssertEqual(body.endedElapsedMs, 90_000)
    }

    // MARK: Outcome

    private func outcome(_ json: String, previousBestStars: Int, previousBestScore: Int) throws -> ChallengeRunOutcome {
        let response = try JSONDecoder().decode(ChallengeCommitResponse.self, from: Data(json.utf8))
        return ChallengeRunOutcome(node: node, response: response, previousBestStars: previousBestStars, previousBestScore: previousBestScore)
    }

    func testWorseReplayKeepsTheBestAndIsNotANewBest() throws {
        let outcome = try outcome("""
        {"runId":"r","status":"committed","result":{"outcome":"cleared","starsThisRun":1,"bestStars":3,"correctMatches":12,
         "mistakes":5,"longestCombo":3,"elapsedMs":80000,"score":900,"bestScore":2000},"unlock":{"kind":"none"},"nextAction":"open_map"}
        """, previousBestStars: 3, previousBestScore: 2000)
        XCTAssertFalse(outcome.isNewBest)
        XCTAssertFalse(outcome.isFirstClear)
        XCTAssertNil(outcome.nextNode)
    }

    func testUnlockKinds() throws {
        let level = try outcome("""
        {"result":{"outcome":"cleared","starsThisRun":2,"bestStars":2,"correctMatches":12,"mistakes":1,"longestCombo":8,
         "elapsedMs":68600,"score":1685,"bestScore":1685},"unlock":{"kind":"level","chapterNo":1,"levelNo":3},"nextAction":"play_next_level"}
        """, previousBestStars: 0, previousBestScore: 0)
        XCTAssertEqual(level.nextNode, ChallengeNodeRef(chapterNo: 1, levelNo: 3))
        XCTAssertTrue(level.isFirstClear)
        XCTAssertFalse(level.chapterCleared)

        let ready = try outcome("""
        {"result":{"outcome":"cleared","starsThisRun":1,"bestStars":1,"correctMatches":16,"mistakes":4,"longestCombo":5,
         "elapsedMs":88000,"score":1500,"bestScore":1500},"unlock":{"kind":"chapter_ready","chapterNo":2},"nextAction":"play_next_level"}
        """, previousBestStars: 0, previousBestScore: 0)
        XCTAssertEqual(ready.nextNode, ChallengeNodeRef(chapterNo: 2, levelNo: 1))
        XCTAssertTrue(ready.chapterCleared)

        let words = try outcome("""
        {"result":{"outcome":"cleared","starsThisRun":1,"bestStars":1,"correctMatches":16,"mistakes":4,"longestCombo":5,
         "elapsedMs":88000,"score":1500,"bestScore":1500},
         "unlock":{"kind":"needs_vocabulary","chapterNo":2,"eligibleNewCount":9,"requiredNewCount":12},"nextAction":"learn_more"}
        """, previousBestStars: 0, previousBestScore: 0)
        XCTAssertNil(words.nextNode)
        XCTAssertEqual(words.wordsNeeded, ChallengeRunOutcome.WordsNeeded(chapterNo: 2, eligible: 9, required: 12))
    }
}

@MainActor
final class ChallengeMapTests: XCTestCase {
    private func decode(_ json: String) throws -> ChallengeMap {
        try JSONDecoder().decode(ChallengeMap.self, from: Data(json.utf8))
    }

    func testDecodesAMapAndToleratesUnknownStates() throws {
        // The example from FRONTEND_FLOW.md §12.1, with one state the client doesn't know yet.
        let map = try decode("""
        { "configVersion": "match-madness-trial-v1", "gameMode": "match_madness",
          "chapters": [
            { "id": "c1", "chapterNo": 1, "state": "active", "titleKey": "challenge.chapter.1", "explanationLocale": "vi-VN",
              "coreMeaningCount": 12, "reviewMeaningCount": 0, "starsEarned": 1, "maxStars": 9,
              "levels": [
                { "levelNo": 1, "state": "cleared", "bestStars": 1, "bestScore": 1020 },
                { "levelNo": 2, "state": "available", "bestStars": 0, "bestScore": 0 },
                { "levelNo": 3, "state": "something_new", "bestStars": 0, "bestScore": 0 } ] } ],
          "nextChapter": { "chapterNo": 2, "state": "locked", "eligibleNewCount": 4, "requiredNewCount": 12 },
          "currentNode": { "chapterNo": 1, "levelNo": 2 } }
        """)
        XCTAssertEqual(map.chapters[0].levels[2].state, .unknown)
        XCTAssertFalse(map.chapters[0].levels[2].isPlayable)
        XCTAssertEqual(map.chapters[0].maxStars, 9)
        XCTAssertEqual(map.nextChapter?.remainingNewCount, 8)
        XCTAssertEqual(ChallengeHomeSummary(map: map), .inProgress(chapterNo: 1, levelNo: 2, earnedStars: 1, maxStars: 9))
    }

    func testHomeSummaryStates() {
        XCTAssertEqual(ChallengeHomeSummary(map: .previewNotEligible), .notYetEligible(eligible: 7, required: 12))

        let ready = ChallengeMap(
            chapters: [],
            nextChapter: ChallengeChapterPreview(chapterNo: 1, state: .ready, eligibleNewCount: 12, requiredNewCount: 12),
            currentNode: nil
        )
        XCTAssertEqual(ChallengeHomeSummary(map: ready), .chapterReady(chapterNo: 1))

        var chapter = ChallengeMap.preview.chapters[1]
        chapter = ChallengeChapter(
            id: chapter.id, chapterNo: chapter.chapterNo, state: .contentUnavailable, explanationLocale: chapter.explanationLocale,
            starsEarned: chapter.starsEarned, maxStars: chapter.maxStars, levels: chapter.levels
        )
        let unavailable = ChallengeMap(chapters: [ChallengeMap.preview.chapters[0], chapter], nextChapter: ChallengeMap.preview.nextChapter, currentNode: nil)
        XCTAssertEqual(ChallengeHomeSummary(map: unavailable), .contentUnavailable(chapterNo: 2, earnedStars: 1, maxStars: 9))

        let done = ChallengeMap(
            chapters: [ChallengeMap.preview.chapters[0]],
            nextChapter: ChallengeChapterPreview(chapterNo: 2, state: .needsVocabulary, eligibleNewCount: 5, requiredNewCount: 12),
            currentNode: nil
        )
        XCTAssertEqual(ChallengeHomeSummary(map: done), .chapterComplete(chapterNo: 1, earnedStars: 7, maxStars: 9, nextEligible: 5, nextRequired: 12))
    }

    func testRefreshMarksNewlyUnlockedLevelsOnce() async {
        let api = StubVocabAPI()
        let store = ChallengeMapStore(api: api)
        api.challengeMapResult = .success(.preview)
        await store.refresh()
        XCTAssertTrue(store.newlyUnlocked.isEmpty, "Nothing animates on the first load")

        var chapters = ChallengeMap.preview.chapters
        chapters[1] = ChallengeChapter(
            id: "preview-2", chapterNo: 2, state: .active, explanationLocale: "vi-VN", starsEarned: 3, maxStars: 9,
            levels: [.preview(1, state: .cleared, bestStars: 1), .preview(2, state: .cleared, bestStars: 2), .preview(3, state: .available)]
        )
        api.challengeMapResult = .success(ChallengeMap(chapters: chapters, nextChapter: ChallengeMap.preview.nextChapter, currentNode: ChallengeNodeRef(chapterNo: 2, levelNo: 3)))
        await store.refresh()
        let level3 = ChallengeNodeRef(chapterNo: 2, levelNo: 3)
        XCTAssertEqual(store.newlyUnlocked, [level3])
        store.consumeUnlock(level3)
        XCTAssertTrue(store.newlyUnlocked.isEmpty)
    }

    func testFailedRefreshKeepsTheMap() async {
        let api = StubVocabAPI()
        let store = ChallengeMapStore(api: api)
        api.challengeMapResult = .success(.preview)
        await store.refresh()
        api.challengeMapResult = .failure(.transport)
        await store.refresh()
        XCTAssertEqual(store.map, .preview)
        XCTAssertNotNil(store.error)
    }
}
