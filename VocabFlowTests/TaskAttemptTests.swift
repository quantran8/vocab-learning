import XCTest
@testable import VocabFlow

final class TaskAttemptTests: XCTestCase {
    func testNormalizeMatchesTheBackend() {
        XCTAssertEqual(PracticeAnswer.normalize("  New \t\n  York "), "new york")
        XCTAssertEqual(PracticeAnswer.normalize("cafe\u{301}"), "caf\u{E9}")
        XCTAssertNotEqual(PracticeAnswer.normalize("cafe"), PracticeAnswer.normalize("café"))
        XCTAssertEqual(PracticeAnswer.normalize("it's!"), "it's!")
    }

    func testGraphemesCountClustersOfTheNFCString() {
        XCTAssertEqual(PracticeAnswer.graphemes("cafe\u{301}s").count, 5)
        XCTAssertEqual(PracticeAnswer.graphemes("a👍🏽b"), ["a", "👍🏽", "b"])
    }

    func testSeqIncreasesAcrossEveryEventKind() {
        var attempt = TaskAttempt(task: PracticeFixtures.reorder(), phase: .randomPractice)
        attempt.tapTile(2)
        attempt.tapTile(1)
        attempt.removeTile(1)
        attempt.useHint()
        XCTAssertEqual(attempt.events.map(\.seq), [1, 2, 3, 4])
    }

    func testNoEventsAfterACorrectSubmit() {
        var attempt = TaskAttempt(task: PracticeFixtures.choice(), phase: .dueReview)
        XCTAssertEqual(attempt.submitOption(7), false)
        attempt.tryAgain()
        XCTAssertEqual(attempt.submitOption(3), true)
        let count = attempt.events.count
        attempt.reveal()
        XCTAssertNil(attempt.submitOption(3))
        XCTAssertEqual(attempt.events.count, count)
        XCTAssertEqual(attempt.status, .solved)
    }

    func testUnknownOptionIsNotRecorded() {
        var attempt = TaskAttempt(task: PracticeFixtures.choice(), phase: .dueReview)
        XCTAssertNil(attempt.submitOption(99))
        XCTAssertTrue(attempt.events.isEmpty)
    }

    func testFirstRecallCannotBeRevealedBeforeASubmit() {
        var attempt = TaskAttempt(task: PracticeFixtures.typing(), phase: .newPractice)
        XCTAssertTrue(attempt.requiresSubmission)
        XCTAssertFalse(attempt.canReveal)
        attempt.reveal()
        XCTAssertTrue(attempt.events.isEmpty)

        attempt.submitText("wrong")
        XCTAssertTrue(attempt.canReveal)
        attempt.reveal()
        XCTAssertEqual(attempt.status, .revealed)
    }

    func testReviewRecallCanBeRevealedStraightAway() {
        var attempt = TaskAttempt(task: PracticeFixtures.typing(), phase: .dueReview)
        XCTAssertTrue(attempt.canReveal)
        attempt.reveal()
        XCTAssertEqual(attempt.events.map(\.action), [.reveal])
    }

    func testTypedValueIsCappedAtTheBackendLimit() {
        var attempt = TaskAttempt(task: PracticeFixtures.typing(), phase: .dueReview)
        attempt.submitText(String(repeating: "x", count: 500))
        guard case .submitValue(let value) = attempt.events.first?.action else { return XCTFail("No submit") }
        XCTAssertEqual(value.utf16.count, TaskAttempt.maxValueLength)
    }

    func testBlankTextIsNotAnAttempt() {
        var attempt = TaskAttempt(task: PracticeFixtures.typing(), phase: .dueReview)
        XCTAssertNil(attempt.submitText("   "))
        XCTAssertTrue(attempt.events.isEmpty)
    }

    func testTileSubmitMatchesTheReplayedRow() {
        var attempt = TaskAttempt(task: PracticeFixtures.reorder(), phase: .randomPractice)
        attempt.tapTile(1)
        attempt.tapTile(2)
        attempt.moveTile(2, to: 0)
        XCTAssertEqual(attempt.submitTiles(), true)
        XCTAssertEqual(attempt.events.last?.action, .submitTiles([2, 1]))
    }

    func testTileTapRules() {
        var attempt = TaskAttempt(task: PracticeFixtures.reorder(), phase: .randomPractice)
        attempt.tapTile(1)
        attempt.tapTile(1)
        attempt.removeTile(2)
        attempt.moveTile(1, to: 3)
        XCTAssertEqual(attempt.events.map(\.action), [.tapTile(1)])
    }

    func testMatchEndsWhenEveryPairIsRight() {
        var attempt = TaskAttempt(task: PracticeFixtures.match(), phase: .randomPractice)
        XCTAssertEqual(attempt.submitPair(leftID: 1, rightID: 6), false)
        XCTAssertEqual(attempt.submitPair(leftID: 1, rightID: 5), true)
        XCTAssertNil(attempt.submitPair(leftID: 1, rightID: 5), "A solved pair can't be sent again")
        XCTAssertFalse(attempt.isFinished)
        XCTAssertEqual(attempt.submitPair(leftID: 2, rightID: 6), true)
        XCTAssertEqual(attempt.status, .solved)
    }

    func testSurgeryNeedsPositionAndReplacement() {
        var attempt = TaskAttempt(task: PracticeFixtures.surgery(), phase: .dueReview)
        XCTAssertEqual(attempt.submitRepair(graphemeIndex: 3, replacement: ""), false)
        attempt.tryAgain()
        XCTAssertEqual(attempt.submitRepair(graphemeIndex: 4, replacement: "x"), false)
        attempt.tryAgain()
        XCTAssertEqual(attempt.submitRepair(graphemeIndex: 4, replacement: "  "), true, "Blank means delete")
        XCTAssertEqual(attempt.solutionText, "clarify")
    }

    func testRecordingHasExactlyOneEvent() {
        var attempt = TaskAttempt(task: PracticeFixtures.recording(), phase: .newPractice)
        attempt.finishRecording(receiptID: "r1")
        attempt.markRecordingUnavailable(reason: "x")
        XCTAssertEqual(attempt.events, [TaskEvent(seq: 1, action: .assessed(receiptID: "r1"))])
    }

    func testRecordingCanNotBeRevealed() {
        XCTAssertFalse(TaskAttempt(task: PracticeFixtures.recording(), phase: .newPractice).canReveal)
    }

    func testDeliveryModeIsTruthful() {
        XCTAssertNil(TaskAttempt(task: PracticeFixtures.typing(), phase: .dueReview).deliveryMode)

        var attempt = TaskAttempt(task: PracticeFixtures.typing(prompt: .audio(PracticeFixtures.clip)), phase: .dueReview)
        XCTAssertEqual(attempt.deliveryMode, DeliveryMode.none, "Never played")
        attempt.recordAudioPlayback(succeeded: false)
        XCTAssertEqual(attempt.deliveryMode, .fallback)
        attempt.recordAudioPlayback(succeeded: true)
        XCTAssertEqual(attempt.deliveryMode, .audio)
        attempt.recordAudioPlayback(succeeded: false)
        XCTAssertEqual(attempt.deliveryMode, .audio, "Sound that reached the learner stays delivered")
    }

    func testEventLimitEndsATaskValidly() {
        var attempt = TaskAttempt(task: PracticeFixtures.reorder(), phase: .newPractice)
        while !attempt.isFinished {
            attempt.tapTile(1)
            if !attempt.isFinished { attempt.removeTile(1) }
        }
        XCTAssertEqual(attempt.events.count, TaskAttempt.maxEvents)
        XCTAssertEqual(attempt.submitCount, 1, "First recall still ends on a submit")
    }

    func testEventLimitRevealsAnUnfinishedMatch() {
        var attempt = TaskAttempt(task: PracticeFixtures.match(), phase: .randomPractice)
        while !attempt.isFinished {
            attempt.submitPair(leftID: 1, rightID: 6)
        }
        XCTAssertEqual(attempt.status, .revealed)
        XCTAssertEqual(attempt.events.count, TaskAttempt.maxEvents)
    }

    func testLastTryEndsTheTaskWithNoExtraEvent() {
        var attempt = TaskAttempt(task: PracticeFixtures.choice(maxRetries: 1), phase: .dueReview)
        attempt.submitOption(7)
        XCTAssertEqual(attempt.status, .wrong)
        attempt.tryAgain()
        attempt.submitOption(7)
        XCTAssertEqual(attempt.status, .exhausted)
        XCTAssertEqual(attempt.events.map(\.action), [.submitOption(7), .submitOption(7)])

        attempt.tryAgain()
        XCTAssertNil(attempt.submitOption(3), "A submit past the limit rejects the commit")
        XCTAssertEqual(attempt.submitCount, 2)
    }

    func testLastTryCanStillBeRight() {
        var attempt = TaskAttempt(task: PracticeFixtures.choice(maxRetries: 1), phase: .dueReview)
        attempt.submitOption(7)
        attempt.tryAgain()
        XCTAssertEqual(attempt.submitOption(3), true)
        XCTAssertEqual(attempt.status, .solved)
    }

    func testZeroRetriesAllowsOnlyTheFirstTry() {
        var attempt = TaskAttempt(task: PracticeFixtures.choice(maxRetries: 0), phase: .dueReview)
        attempt.submitOption(7)
        XCTAssertEqual(attempt.status, .exhausted)
    }

    func testNoLimitWhenThePlanHasNone() {
        var attempt = TaskAttempt(task: PracticeFixtures.choice(), phase: .dueReview)
        for _ in 0..<5 {
            attempt.submitOption(7)
            attempt.tryAgain()
        }
        XCTAssertEqual(attempt.submitCount, 5)
        XCTAssertEqual(attempt.status, .answering)
    }

    func testMatchCountsTriesPerLeftItem() {
        var attempt = TaskAttempt(task: PracticeFixtures.match(maxRetries: 1), phase: .randomPractice)
        attempt.submitPair(leftID: 1, rightID: 6)
        attempt.submitPair(leftID: 2, rightID: 5)
        XCTAssertTrue(attempt.exhaustedLeftIDs.isEmpty, "One miss each, not two on the same item")

        attempt.submitPair(leftID: 1, rightID: 6)
        XCTAssertEqual(attempt.exhaustedLeftIDs, [1])
        XCTAssertNil(attempt.submitPair(leftID: 1, rightID: 5), "An item out of tries can't be sent again")
        XCTAssertFalse(attempt.isFinished)
    }

    func testMatchItemOutOfTriesDoesNotBlockTheBoard() {
        var attempt = TaskAttempt(task: PracticeFixtures.match(maxRetries: 0), phase: .randomPractice)
        attempt.submitPair(leftID: 1, rightID: 6)
        XCTAssertEqual(attempt.submitPair(leftID: 2, rightID: 6), true)
        XCTAssertEqual(attempt.status, .exhausted)
        XCTAssertEqual(attempt.events.count, 2, "Ending adds no reveal")
        XCTAssertEqual(attempt.missedPairsText, "a — x", "Only the pair that was missed")
    }

    func testAllPairsTextListsEveryPairOfAMatchAndNothingElse() {
        let match = TaskAttempt(task: PracticeFixtures.match(), phase: .randomPractice)
        XCTAssertEqual(match.allPairsText, "a — x\nb — y")

        let surgery = TaskAttempt(task: PracticeFixtures.surgery(), phase: .randomPractice)
        XCTAssertNil(surgery.allPairsText)
    }

    func testRecordingCountsEveryAssessment() {
        var attempt = TaskAttempt(task: PracticeFixtures.recording(maxRetries: 1), phase: .newPractice)
        attempt.countAssessment()
        XCTAssertTrue(attempt.canRecordAgain)
        attempt.countAssessment()
        XCTAssertFalse(attempt.canRecordAgain)
    }

    func testEventsEncodeOnlyTheirOwnFields() throws {
        let cases: [(TaskEvent.Action, [String: AnyHashable])] = [
            (.submitOption(2), ["seq": 1, "action": "submit", "optionId": 2]),
            (.submitValue("x"), ["seq": 1, "action": "submit", "value": "x"]),
            (.submitTiles([2, 3]), ["seq": 1, "action": "submit", "tileIds": [2, 3]]),
            (.submitRepair(graphemeIndex: 4, replacement: ""), ["seq": 1, "action": "submit", "graphemeIndex": 4, "replacement": ""]),
            (.pair(leftID: 1, rightID: 5), ["seq": 1, "action": "pair", "leftId": 1, "rightId": 5]),
            (.tapTile(1), ["seq": 1, "action": "tap_tile", "tileId": 1]),
            (.removeTile(1), ["seq": 1, "action": "remove_tile", "tileId": 1]),
            (.moveTile(1, toIndex: 0), ["seq": 1, "action": "move_tile", "tileId": 1, "toIndex": 0]),
            (.hint, ["seq": 1, "action": "hint"]),
            (.reveal, ["seq": 1, "action": "reveal"]),
            (.assessed(receiptID: "r"), ["seq": 1, "action": "assessed", "assessmentReceiptId": "r"]),
            (.unavailable(reason: "x"), ["seq": 1, "action": "unavailable", "reason": "x"]),
        ]
        for (action, expected) in cases {
            let encoded = try PracticeFixtures.json(TaskEvent(seq: 1, action: action)) as? [String: AnyHashable]
            XCTAssertEqual(encoded, expected)
        }
    }

    func testTextPromptOmitsDeliveryMode() throws {
        let attempt = TaskAttempt(task: PracticeFixtures.typing(), phase: .dueReview)
        let encoded = try PracticeFixtures.json(attempt.result) as? [String: Any]
        XCTAssertNil(encoded?["deliveryMode"])
    }
}
