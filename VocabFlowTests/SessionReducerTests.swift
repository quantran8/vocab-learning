import XCTest
@testable import VocabFlow

final class SessionReducerTests: XCTestCase {
    private var content: DemoContent!

    override func setUpWithError() throws {
        content = try TestContent.demo()
    }

    func testStartBeginsLearnAndLearnFlowsToBuild() {
        let started = TestContent.reduce(SessionState(), .start, content: content).state
        XCTAssertEqual(started.phase, .learn(index: 0))

        let built = TestContent.atBuild(content)
        XCTAssertEqual(built.phase, .build(index: 0))
    }

    func testCorrectTileAcceptedAndDistractorRejectedWithoutAdvance() {
        let challenge = content.buildChallenges[0]
        let state = TestContent.atBuild(content)

        let wrong = TestContent.reduce(state, .buildSubmitted(tileID: TestContent.distractor(challenge)), .advance, content: content)
        XCTAssertEqual(wrong.state.phase, .build(index: 0))
        XCTAssertEqual(wrong.state.feedback, .buildIncorrect(tileID: TestContent.distractor(challenge)))
        XCTAssertEqual(wrong.events, [.incorrect])

        let right = TestContent.reduce(wrong.state, .buildSubmitted(tileID: challenge.acceptedOptionIDs[0]), content: content)
        XCTAssertEqual(right.state.feedback, .buildCorrect(tileID: challenge.acceptedOptionIDs[0]))
        XCTAssertEqual(right.events, [.correct])
        XCTAssertEqual(TestContent.reduce(right.state, .advance, content: content).state.phase, .build(index: 1))
    }

    func testDuplicateSubmissionDuringFeedbackRecordsOnce() {
        let challenge = content.buildChallenges[0]
        let correct = challenge.acceptedOptionIDs[0]
        let wrong = TestContent.distractor(challenge)

        let afterCorrect = TestContent.reduce(TestContent.atBuild(content), .buildSubmitted(tileID: correct), .buildSubmitted(tileID: correct), .buildSubmitted(tileID: wrong), content: content)
        XCTAssertEqual(afterCorrect.state.attempts.count, 1)
        XCTAssertEqual(afterCorrect.events, [.correct])

        let afterWrong = TestContent.reduce(TestContent.atBuild(content), .buildSubmitted(tileID: wrong), .buildSubmitted(tileID: wrong), content: content)
        XCTAssertEqual(afterWrong.state.attempts.count, 1)

        var recall = TestContent.atRecall(content)
        recall = TestContent.reduce(recall, .recallSubmitted("nope"), .recallSubmitted(" Nope "), content: content).state
        XCTAssertEqual(recall.attempts.filter { $0.stage == .recall }.count, 1)
    }

    func testAdvanceDoesNotSkipUnfinishedChallenges() {
        let state = TestContent.atBuild(content)
        XCTAssertEqual(TestContent.reduce(state, .advance, .advance, content: content).state.phase, .build(index: 0))

        let recall = TestContent.atRecall(content)
        XCTAssertEqual(TestContent.reduce(recall, .advance, content: content).state.phase, .recall(index: 0))
    }

    func testHintBeforeCorrectRecallIsHinted() {
        let word = content.words[0]
        let state = TestContent.reduce(TestContent.atRecall(content), .hintRequested, .recallSubmitted(word.term), content: content).state
        XCTAssertEqual(state.recallOutcomes[word.id], .hintedRecall)
        XCTAssertEqual(state.hintsByWordID[word.id], 1)
    }

    func testFirstTryWithoutHintIsUnaidedAndNormalizes() {
        let word = content.words[0]
        let state = TestContent.reduce(TestContent.atRecall(content), .recallSubmitted("  \(word.term.uppercased())\n"), content: content).state
        XCTAssertEqual(state.recallOutcomes[word.id], .unaidedRecall)
    }

    func testWrongThenCorrectIsNotUnaided() {
        let word = content.words[0]
        let state = TestContent.reduce(TestContent.atRecall(content), .recallSubmitted("apprecate"), .recallSubmitted(word.term), content: content).state
        XCTAssertEqual(state.recallOutcomes[word.id], .recalledAfterRetry)
        XCTAssertNotEqual(state.recallOutcomes[word.id], .unaidedRecall)
    }

    func testRunningOutOfAttemptsOrRevealingIsNotRecalled() {
        let word = content.words[0]
        let exhausted = TestContent.reduce(TestContent.atRecall(content), .recallSubmitted("a"), .recallSubmitted("b"), .recallSubmitted("c"), .recallSubmitted(word.term), content: content).state
        XCTAssertEqual(exhausted.recallOutcomes[word.id], .notRecalled)
        XCTAssertEqual(exhausted.attempts.filter { $0.stage == .recall }.count, SessionReducer.maxRecallAttempts)

        let revealed = TestContent.reduce(TestContent.atRecall(content), .answerRevealed, content: content).state
        XCTAssertEqual(revealed.recallOutcomes[word.id], .notRecalled)
    }

    func testHintsCapAndCountOncePerUnlock() {
        let word = content.words[0]
        let result = TestContent.reduce(TestContent.atRecall(content), .hintRequested, .hintRequested, .hintRequested, content: content)
        XCTAssertEqual(result.state.hintsByWordID[word.id], HintSequence.maxHints)
        XCTAssertEqual(result.events, Array(repeating: .hintOpened, count: HintSequence.maxHints))
    }

    func testRestartClearsEverything() {
        let mid = TestContent.reduce(TestContent.atRecall(content), .hintRequested, .recallSubmitted("x"), content: content).state
        let restarted = TestContent.reduce(mid, .restart, content: content)
        XCTAssertEqual(restarted.state, SessionState())
        XCTAssertEqual(restarted.state.phase, .home)
        XCTAssertEqual(restarted.events, [.restarted])
    }

    func testResultTotalsSeparateRecognitionFromRecall() {
        var state = TestContent.atRecall(content)
        state = TestContent.reduce(state, .recallSubmitted(content.words[0].term), .advance, content: content).state
        state = TestContent.reduce(state, .hintRequested, .recallSubmitted(content.words[1].term), .advance, content: content).state
        state = TestContent.reduce(state, .answerRevealed, .advance, content: content).state
        XCTAssertEqual(state.phase, .results)

        let result = SessionReducer.result(state: state, content: content)
        XCTAssertEqual(result.totalWords, 3)
        XCTAssertEqual(result.recognizedCount, 3)
        XCTAssertEqual(result.unaidedCount, 1)
        XCTAssertEqual(result.hintedCount, 1)
        XCTAssertEqual(result.notRecalledCount, 1)
        XCTAssertEqual(result.wordsToReview.map(\.wordID), [content.words[1].id, content.words[2].id])
    }

    func testRecognizedNeverCountsAsRecall() {
        let state = TestContent.atRecall(content)
        let result = SessionReducer.result(state: state, content: content)
        XCTAssertEqual(result.recognizedCount, 3)
        XCTAssertEqual(result.unaidedCount + result.hintedCount + result.afterRetryCount, 0)
    }
}
