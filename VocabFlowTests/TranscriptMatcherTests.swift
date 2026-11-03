import XCTest
@testable import VocabFlow

final class TranscriptMatcherTests: XCTestCase {
    func testExactMatchIgnoringCaseAndPunctuationPasses() {
        let assessment = TranscriptMatcher.assess(["Appreciate!"], target: "appreciate")
        XCTAssertEqual(assessment.passed, true)
    }

    func testTakesCarryNoScore() {
        XCTAssertNil(TranscriptMatcher.assess(["appreciate"], target: "appreciate").accuracyScore)
        XCTAssertNil(TranscriptMatcher.assess(["apple"], target: "appreciate").accuracyScore)
    }

    func testOnlyTopCandidateCounts() {
        let assessment = TranscriptMatcher.assess(["a precious", "appreciate"], target: "appreciate")
        XCTAssertEqual(assessment.heard, "a precious")
        XCTAssertEqual(assessment.passed, false)
    }

    func testDifferentWordFails() {
        let assessment = TranscriptMatcher.assess(["apricot"], target: "appreciate")
        XCTAssertEqual(assessment.isValid, true)
        XCTAssertEqual(assessment.passed, false)
    }

    func testNearMatchFails() {
        XCTAssertEqual(TranscriptMatcher.assess(["appreciates"], target: "appreciate").passed, false)
        XCTAssertEqual(TranscriptMatcher.assess(["the cat sat on the hat"], target: "the cat sat on the mat").passed, false)
    }

    func testNothingRecognizedIsInvalid() {
        let assessment = TranscriptMatcher.assess(["", " . "], target: "appreciate")
        XCTAssertFalse(assessment.isValid)
        XCTAssertNil(assessment.passed)
    }
}
