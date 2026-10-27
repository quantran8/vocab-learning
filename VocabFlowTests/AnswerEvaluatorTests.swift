import XCTest
@testable import VocabFlow

final class AnswerEvaluatorTests: XCTestCase {
    private let word = VocabularyItem(id: "improve", term: "improve", meaningVi: "cải thiện", example: "We need to improve the process.")

    func testTrimsWhitespaceAndIgnoresCase() {
        XCTAssertTrue(AnswerEvaluator.isCorrect(typed: "  Improve \n", for: word))
        XCTAssertTrue(AnswerEvaluator.isCorrect(typed: "IMPROVE", for: word))
    }

    func testDoesNotAutocorrectNearMisses() {
        XCTAssertFalse(AnswerEvaluator.isCorrect(typed: "improv", for: word))
        XCTAssertFalse(AnswerEvaluator.isCorrect(typed: "improves", for: word))
        XCTAssertFalse(AnswerEvaluator.isCorrect(typed: "im prove", for: word))
        XCTAssertFalse(AnswerEvaluator.isCorrect(typed: "   ", for: word))
    }

    func testUnicodeCanonicalEquivalence() {
        let decomposed = "cafe\u{0301}"
        let item = VocabularyItem(id: "cafe", term: "café", meaningVi: "quán cà phê", example: "Meet me at the café.")
        XCTAssertTrue(AnswerEvaluator.isCorrect(typed: decomposed, for: item))
    }

    func testAcceptsOnlyDeclaredInflections() {
        var item = word
        XCTAssertFalse(AnswerEvaluator.isCorrect(typed: "improved", for: item))
        item.acceptedForms = ["improved"]
        XCTAssertTrue(AnswerEvaluator.isCorrect(typed: "Improved", for: item))
    }

    func testBuildEvaluationUsesIDsNotText() {
        let challenge = BuildChallenge(
            id: "c", wordID: "improve", context: "ctx", prompt: "We need to ___ it.",
            options: [WordOption(id: "a", text: "improve"), WordOption(id: "b", text: "improve")],
            acceptedOptionIDs: ["a"], explanations: [:]
        )
        XCTAssertTrue(AnswerEvaluator.isCorrect(tileID: "a", for: challenge))
        XCTAssertFalse(AnswerEvaluator.isCorrect(tileID: "b", for: challenge))
    }

    func testHintSequenceIsDeterministic() {
        XCTAssertNil(HintSequence.hint(for: "improve", level: 0))
        XCTAssertEqual(HintSequence.hint(for: "improve", level: 1), "i _ _ _ _ _ _")
        XCTAssertEqual(HintSequence.hint(for: "improve", level: 2), "i m p r _ _ _")
    }
}
