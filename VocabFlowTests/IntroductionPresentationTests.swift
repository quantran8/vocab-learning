import XCTest
@testable import VocabFlow

final class IntroductionPresentationTests: XCTestCase {
    func testExactlySixWordOnlyTemplates() {
        XCTAssertEqual(
            IntroductionTemplateID.allCases.map(\.rawValue),
            ["letterCascade", "wordAssemble", "letterWave", "swipeReveal", "flipLetters", "chunkMerge"]
        )
    }

    func testSeededWordsHaveStableAuthoredTemplates() throws {
        let content = try TestContent.demo()
        let mapping = Dictionary(uniqueKeysWithValues: content.words.map { ($0.id, $0.introPresentation.templateID) })
        XCTAssertEqual(mapping["appreciate"], .chunkMerge)
        XCTAssertEqual(mapping["consider"], .letterWave)
        XCTAssertEqual(mapping["improve"], .swipeReveal)
        // Re-reading yields the same choice: never random per render.
        XCTAssertEqual(try TestContent.demo().words.map(\.introPresentation), content.words.map(\.introPresentation))
    }

    func testAppreciateChunksJoinExactlyWithoutSpaces() throws {
        let word = try XCTUnwrap(TestContent.demo().word(id: "appreciate"))
        let chunks = try XCTUnwrap(word.introPresentation.introChunks)
        XCTAssertEqual(chunks, ["ap", "pre", "ciate"])
        XCTAssertEqual(chunks.joined(), "appreciate")
        XCTAssertFalse(chunks.joined().contains(" "))
    }

    func testChunksAreCuratedNotDerivedFromSyllables() throws {
        let word = try XCTUnwrap(TestContent.demo().word(id: "appreciate"))
        XCTAssertNotEqual(word.introPresentation.introChunks, word.syllables)
    }

    func testChunkValidation() {
        XCTAssertTrue(IntroductionPresentation.areValidChunks(["im", "prove"], for: "improve"))
        XCTAssertFalse(IntroductionPresentation.areValidChunks(nil, for: "improve"))
        XCTAssertFalse(IntroductionPresentation.areValidChunks([], for: "improve"))
        XCTAssertFalse(IntroductionPresentation.areValidChunks(["im", "", "prove"], for: "improve"))
        XCTAssertFalse(IntroductionPresentation.areValidChunks(["im", "prov"], for: "improve"))
        XCTAssertFalse(IntroductionPresentation.areValidChunks(["im", " prove"], for: "improve"))
        XCTAssertFalse(IntroductionPresentation.areValidChunks(["Im", "prove"], for: "improve"))
    }

    func testInvalidChunkMergeFallsBackToSwipeReveal() {
        let missing = IntroductionPresentation(templateID: .chunkMerge, introChunks: nil).resolved(for: "improve")
        XCTAssertEqual(missing.templateID, .swipeReveal)
        let incomplete = IntroductionPresentation(templateID: .chunkMerge, introChunks: ["im"]).resolved(for: "improve")
        XCTAssertEqual(incomplete.templateID, .swipeReveal)
        let valid = IntroductionPresentation(templateID: .chunkMerge, introChunks: ["im", "prove"]).resolved(for: "improve")
        XCTAssertEqual(valid.templateID, .chunkMerge)
    }

    func testSwitchingKeepsChunksAndOtherTemplatesNeedOnlyTheWord() {
        let base = IntroductionPresentation(templateID: .letterWave, introChunks: ["con", "si", "der"])
        XCTAssertEqual(base.switched(to: .chunkMerge, for: "consider").templateID, .chunkMerge)
        for id in IntroductionTemplateID.allCases where id != .chunkMerge {
            XCTAssertEqual(IntroductionPresentation(templateID: id).resolved(for: "consider").templateID, id)
        }
    }

    func testValidatorFlagsMalformedChunks() throws {
        var content = try TestContent.demo()
        content.words[0].intro = IntroductionPresentation(templateID: .chunkMerge, introChunks: ["ap", "pre"])
        XCTAssertTrue(ContentValidator.validate(content).contains(.invalidIntroChunks(wordID: content.words[0].id)))
    }

    func testIntroductionNeverChangesScoring() throws {
        // Learn only advances via an explicit action; the intro recipe is not part of session state.
        let content = try TestContent.demo()
        let atLearn = TestContent.reduce(SessionState(), .start, content: content).state
        XCTAssertEqual(atLearn.phase, .learn(index: 0))
        XCTAssertTrue(atLearn.attempts.isEmpty)
        XCTAssertTrue(atLearn.hintsByWordID.isEmpty)
        let next = TestContent.reduce(atLearn, .learnedNext, content: content).state
        XCTAssertEqual(next.phase, .learn(index: 1))
        XCTAssertTrue(next.attempts.isEmpty)
    }
}
