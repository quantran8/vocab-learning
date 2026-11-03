import XCTest
@testable import VocabFlow

final class TranscriptMatcherTests: XCTestCase {
    func testExactMatchIgnoringCaseAndPunctuationPasses() {
        let assessment = TranscriptMatcher.assess(["Appreciate!"], target: "appreciate")
        XCTAssertEqual(assessment.accuracyScore, 100)
        XCTAssertEqual(assessment.passed, true)
    }

    func testBestCandidateIsScored() {
        let assessment = TranscriptMatcher.assess(["a precious", "appreciates"], target: "appreciate")
        XCTAssertEqual(assessment.heard, "appreciates")
        XCTAssertEqual(assessment.passed, true)
    }

    func testDifferentWordFails() {
        let assessment = TranscriptMatcher.assess(["apricot"], target: "appreciate")
        XCTAssertEqual(assessment.isValid, true)
        XCTAssertEqual(assessment.passed, false)
    }

    func testNothingRecognizedIsInvalid() {
        let assessment = TranscriptMatcher.assess(["", " . "], target: "appreciate")
        XCTAssertFalse(assessment.isValid)
        XCTAssertNil(assessment.passed)
    }
}
