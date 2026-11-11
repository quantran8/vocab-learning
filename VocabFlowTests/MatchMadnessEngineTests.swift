import XCTest
@testable import VocabFlow

final class ChallengeBoardOrderingTests: XCTestCase {
    /// The shared vectors from vocab-backend `match-madness.spec.ts` / `FRONTEND_FLOW.md` §12.3.
    func testBackendSharedVectors() {
        let seed = "00112233445566778899aabbccddeeff"
        let ids = (1...3).map { "018f0000-0000-7000-8000-00000000000\($0)" }
        XCTAssertEqual(
            ChallengeBoardOrdering.sortKey(seed: seed, correctCount: 0, side: .word, tileID: ids[0]),
            "a1eedcdd4a2b5f8ffd4f2133437cc340a0fcb76214ccc2dd789dbc2aac1a8158"
        )
        XCTAssertEqual(ChallengeBoardOrdering.order(ids, seed: seed, correctCount: 0, side: .word), [ids[0], ids[2], ids[1]])
        XCTAssertEqual(ChallengeBoardOrdering.order(ids, seed: seed, correctCount: 0, side: .meaning), [ids[1], ids[0], ids[2]])
        XCTAssertEqual(ChallengeBoardOrdering.order(ids, seed: seed, correctCount: 1, side: .word), [ids[0], ids[1], ids[2]])
        XCTAssertEqual(ChallengeBoardOrdering.order(ids, seed: seed, correctCount: 1, side: .meaning), [ids[0], ids[2], ids[1]])
    }

    // Reference values computed independently (Python hashlib).
    func testSortKeyIsLowercaseHexSHA256OfTheJoinedInput() {
        XCTAssertEqual(
            ChallengeBoardOrdering.sortKey(seed: "seed-1", correctCount: 0, side: .word, tileID: "w1"),
            "de72e234e69c3853cfe915c978720dca170567a0e9f9132b3ef7f030c882d22c"
        )
    }

    func testColumnsAreOrderedIndependentlyPerSideAndCorrectCount() {
        let words = ["w1", "w2", "w3", "w4"]
        let meanings = ["m1", "m2", "m3", "m4"]
        XCTAssertEqual(ChallengeBoardOrdering.order(words, seed: "seed-1", correctCount: 0, side: .word), ["w3", "w2", "w4", "w1"])
        XCTAssertEqual(ChallengeBoardOrdering.order(meanings, seed: "seed-1", correctCount: 0, side: .meaning), ["m1", "m4", "m3", "m2"])
        XCTAssertEqual(ChallengeBoardOrdering.order(words, seed: "seed-1", correctCount: 1, side: .word), ["w4", "w2", "w1", "w3"])
        XCTAssertEqual(ChallengeBoardOrdering.order(meanings, seed: "seed-1", correctCount: 2, side: .meaning), ["m4", "m3", "m1", "m2"])
    }

    func testOrderDoesNotDependOnInputOrder() {
        let ids = ["w1", "w2", "w3", "w4"]
        XCTAssertEqual(
            ChallengeBoardOrdering.order(ids.reversed(), seed: "seed-1", correctCount: 0, side: .word),
            ChallengeBoardOrdering.order(ids, seed: "seed-1", correctCount: 0, side: .word)
        )
    }
}

final class MatchMadnessEngineTests: XCTestCase {
    private let plan = ChallengeRunPlan.sandbox(visiblePairs: 4, goalMatches: 6)
    private var engine: MatchMadnessEngine { MatchMadnessEngine(plan: plan) }

    private func run(_ actions: [MatchMadnessAction], from state: MatchMadnessState? = nil) -> (MatchMadnessState, [MatchMadnessFeedback]) {
        var current = state ?? engine.initialState()
        var feedback: [MatchMadnessFeedback] = []
        for action in actions {
            let step = engine.reduce(current, action)
            current = step.state
            feedback.append(step.feedback)
        }
        return (current, feedback)
    }

    func testInitialBoardShowsTheFirstVisiblePairsInSeededOrder() {
        let state = engine.initialState()
        XCTAssertEqual(state.activePairIDs, ["p1", "p2", "p3", "p4"])
        XCTAssertEqual(state.pendingPairIDs, ["p5", "p6"])
        XCTAssertEqual(state.wordOrder, ["w4", "w3", "w2", "w1"])
        XCTAssertEqual(state.meaningOrder, ["m2", "m4", "m1", "m3"])
        XCTAssertEqual(state.provisionalScore, 0)
    }

    func testWordThenMeaningMatches() {
        let (state, feedback) = run([.tapWord(tileID: "w1", elapsedMs: 500), .tapMeaning(tileID: "m1", elapsedMs: 900)])
        XCTAssertEqual(feedback, [.selected, .correct(pairID: "p1", combo: 1)])
        XCTAssertEqual(state.correctCount, 1)
        XCTAssertEqual(state.events, [MatchAttemptEvent(seq: 1, elapsedMs: 900, wordTileId: "w1", meaningTileId: "m1")])
    }

    func testMeaningThenWordMatches() {
        let (state, feedback) = run([.tapMeaning(tileID: "m2", elapsedMs: 100), .tapWord(tileID: "w2", elapsedMs: 200)])
        XCTAssertEqual(feedback.last, .correct(pairID: "p2", combo: 1))
        XCTAssertEqual(state.events.first?.wordTileId, "w2")
        XCTAssertEqual(state.events.first?.meaningTileId, "m2")
    }

    func testSelectionsAloneAreNotEvents() {
        let (state, feedback) = run([
            .tapWord(tileID: "w1", elapsedMs: 100),
            .tapWord(tileID: "w2", elapsedMs: 200),
            .tapWord(tileID: "w2", elapsedMs: 300),
        ])
        XCTAssertEqual(feedback, [.selected, .selected, .deselected])
        XCTAssertNil(state.selectedWordTileID)
        XCTAssertTrue(state.events.isEmpty)
    }

    func testChangingSelectionOnOneSideThenMatching() {
        let (state, _) = run([
            .tapWord(tileID: "w1", elapsedMs: 100),
            .tapWord(tileID: "w3", elapsedMs: 200),
            .tapMeaning(tileID: "m3", elapsedMs: 300),
        ])
        XCTAssertEqual(state.correctCount, 1)
        XCTAssertEqual(state.events.map(\.wordTileId), ["w3"])
    }

    func testWrongPairIsRecordedResetsComboAndKeepsBothTiles() {
        let (state, feedback) = run([
            .tapWord(tileID: "w1", elapsedMs: 100), .tapMeaning(tileID: "m1", elapsedMs: 200),
            .tapWord(tileID: "w2", elapsedMs: 300), .tapMeaning(tileID: "m3", elapsedMs: 400),
        ])
        XCTAssertEqual(feedback.last, .wrong(wordTileID: "w2", meaningTileID: "m3"))
        XCTAssertEqual(state.wrongCount, 1)
        XCTAssertEqual(state.combo, 0)
        XCTAssertEqual(state.longestCombo, 1)
        XCTAssertTrue(state.wordOrder.contains("w2"))
        XCTAssertTrue(state.meaningOrder.contains("m3"))
        // A wrong pair never consumes the queue.
        XCTAssertEqual(state.pendingPairIDs, ["p6"])
        XCTAssertNil(state.selectedWordTileID)
        XCTAssertNil(state.selectedMeaningTileID)
        XCTAssertEqual(state.events.map(\.seq), [1, 2])
    }

    func testCorrectPairIsReplacedFromTheQueueAndColumnsReorder() {
        let (state, _) = run([.tapWord(tileID: "w1", elapsedMs: 100), .tapMeaning(tileID: "m1", elapsedMs: 200)])
        XCTAssertEqual(state.activePairIDs, ["p2", "p3", "p4", "p5"])
        XCTAssertEqual(state.pendingPairIDs, ["p6"])
        XCTAssertEqual(state.wordOrder, ["w3", "w4", "w5", "w2"])
        XCTAssertEqual(state.meaningOrder, ["m4", "m3", "m5", "m2"])
    }

    func testTilesNotOnTheBoardAreIgnored() {
        let (state, feedback) = run([.tapWord(tileID: "w6", elapsedMs: 100), .tapMeaning(tileID: "nope", elapsedMs: 200)])
        XCTAssertEqual(feedback, [MatchMadnessFeedback.none, .none])
        XCTAssertEqual(state, engine.initialState())
    }

    private func repeatPlan(_ pairs: [ChallengePairOccurrence], visible: Int) -> ChallengeRunPlan {
        ChallengeRunPlan(
            runId: "r", gameMode: ChallengeRunPlan.matchMadness, chapterNo: 1, levelNo: 3, policyVersion: "t",
            explanationLocale: nil, goalMatches: pairs.count, visiblePairs: visible, timeLimitMs: 90_000,
            minMatchesBetweenRepeats: 3,
            starCriteria: .init(two: .init(maxElapsedMs: 80_000, maxMistakes: 3), three: .init(maxElapsedMs: 60_000, maxMistakes: 1)),
            boardSeed: "s", pairs: pairs
        )
    }

    private func occurrence(_ id: String, _ word: String) -> ChallengePairOccurrence {
        ChallengePairOccurrence(pairId: id, wordTileId: "w-\(id)", meaningTileId: "m-\(id)", word: word, meaning: "gloss \(word)")
    }

    func testOneMeaningIsNeverOnTheBoardTwice() {
        // Same word twice in a row of the queue: the second waits, and nothing behind it jumps ahead of the rule.
        let engine = MatchMadnessEngine(plan: repeatPlan([occurrence("a", "allocate"), occurrence("b", "allocate"), occurrence("c", "clarify")], visible: 2))
        let state = engine.initialState()
        XCTAssertEqual(state.activePairIDs, ["a", "c"])
        XCTAssertEqual(state.pendingPairIDs, ["b"])
        XCTAssertNil(state.provisionalScore)
    }

    func testARepeatWaitsForMinMatchesBetweenRepeats() {
        let pairs = [occurrence("a", "one"), occurrence("b", "two"), occurrence("c", "three"), occurrence("d", "four"),
                     occurrence("a2", "one"), occurrence("e", "five")]
        let engine = MatchMadnessEngine(plan: repeatPlan(pairs, visible: 2))
        var state = engine.initialState()
        XCTAssertEqual(state.activePairIDs, ["a", "b"])
        func match(_ id: String) {
            state = engine.reduce(state, .tapWord(tileID: "w-\(id)", elapsedMs: state.events.count * 100)).state
            state = engine.reduce(state, .tapMeaning(tileID: "m-\(id)", elapsedMs: state.events.count * 100)).state
        }
        match("a")   // "one" matched at count 1
        XCTAssertEqual(state.activePairIDs, ["b", "c"])
        match("b")
        XCTAssertEqual(state.activePairIDs, ["c", "d"])
        match("c")   // count 3: "one" still too recent, so "five" comes on first
        XCTAssertEqual(state.activePairIDs, ["d", "e"])
        match("d")   // count 4: 4 − 1 ≥ 3, the repeat may come back
        XCTAssertEqual(state.activePairIDs, ["e", "a2"])
    }

    func testRepeatedWordsAreMatchedByOccurrenceNotText() {
        let engine = MatchMadnessEngine(plan: repeatPlan([occurrence("a", "allocate"), occurrence("c", "clarify")], visible: 2))
        var state = engine.initialState()
        state = engine.reduce(state, .tapWord(tileID: "w-a", elapsedMs: 10)).state
        let step = engine.reduce(state, .tapMeaning(tileID: "m-c", elapsedMs: 20))
        XCTAssertEqual(step.feedback, .wrong(wordTileID: "w-a", meaningTileID: "m-c"))
    }

    func testReachingTheGoalEndsTheGameAndIgnoresFurtherTaps() {
        var actions: [MatchMadnessAction] = []
        for index in 1...6 {
            actions += [.tapWord(tileID: "w\(index)", elapsedMs: index * 1000), .tapMeaning(tileID: "m\(index)", elapsedMs: index * 1000 + 100)]
        }
        let (state, feedback) = run(actions)
        XCTAssertEqual(feedback.last, .goalReached)
        XCTAssertEqual(state.phase, .goalReached)
        XCTAssertEqual(state.correctCount, 6)
        XCTAssertEqual(state.longestCombo, 6)
        XCTAssertTrue(state.wordOrder.isEmpty)
        // 600 + 10 × (1+2+3+4+5+5), plus the clear bonus 5 × floor((90000 − 6100) / 1000) = 415.
        XCTAssertEqual(state.provisionalScore, 1215)

        let after = engine.reduce(state, .tapWord(tileID: "w1", elapsedMs: 9_000))
        XCTAssertEqual(after.feedback, .none)
        XCTAssertEqual(after.state, state)
    }

    func testEventTimesNeverGoBackwards() {
        let (state, _) = run([
            .tapWord(tileID: "w1", elapsedMs: 500), .tapMeaning(tileID: "m2", elapsedMs: 800),
            .tapWord(tileID: "w2", elapsedMs: 700), .tapMeaning(tileID: "m2", elapsedMs: 600),
        ])
        // Strictly increasing, as the server requires.
        XCTAssertEqual(state.events.map(\.elapsedMs), [800, 801])
    }

    func testCommitBodyCarriesEveryAttemptAndNoScore() throws {
        let (state, _) = run([
            .tapWord(tileID: "w1", elapsedMs: 100), .tapMeaning(tileID: "m2", elapsedMs: 200),
            .tapWord(tileID: "w1", elapsedMs: 300), .tapMeaning(tileID: "m1", elapsedMs: 400),
        ])
        let body = MatchMadnessEngine.commitBody(state, reason: .timeUp, endedElapsedMs: 90_000)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body.encoded()) as? [String: Any])
        XCTAssertEqual(Set(json.keys), ["events", "endedReason", "endedElapsedMs"])
        XCTAssertEqual(json["endedReason"] as? String, "time_up")
        XCTAssertEqual(json["endedElapsedMs"] as? Int, 90_000)
        let events = try XCTUnwrap(json["events"] as? [[String: Any]])
        XCTAssertEqual(events.count, 2)
        XCTAssertEqual(Set(events[0].keys), ["seq", "type", "elapsedMs", "wordTileId", "meaningTileId"])
        XCTAssertEqual(events[0]["type"] as? String, "match")
        // Encoding is stable, so a retry is byte-identical.
        XCTAssertEqual(try body.encoded(), try body.encoded())
    }
}
