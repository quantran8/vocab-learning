import XCTest
@testable import VocabFlow

final class ContentValidationTests: XCTestCase {
    func testBundledContentIsValidAndSized() throws {
        let content = try TestContent.demo()
        XCTAssertEqual(content.words.count, 3)
        XCTAssertEqual(content.buildChallenges.count, 3)
        XCTAssertEqual(content.recallPrompts.count, 3)
        XCTAssertEqual(ContentValidator.validate(content), [])
    }

    func testEveryBuildChallengeHasExactlyOneAcceptedTargetMatchingItsWord() throws {
        let content = try TestContent.demo()
        for challenge in content.buildChallenges {
            XCTAssertEqual(challenge.acceptedOptionIDs.count, 1, challenge.id)
            let accepted = try XCTUnwrap(challenge.option(id: challenge.acceptedOptionIDs[0]))
            XCTAssertEqual(accepted.text, content.word(id: challenge.wordID)?.term, challenge.id)
            let distractors = challenge.options.filter { $0.id != accepted.id }
            XCTAssertEqual(distractors.count, 2, challenge.id)
            for distractor in distractors {
                XCTAssertNotNil(challenge.explanations[distractor.id], "Missing explanation for \(distractor.id)")
            }
        }
    }

    func testShuffleIsDeterministic() throws {
        let data = try Data(contentsOf: XCTUnwrap(Bundle.main.url(forResource: "demo_words", withExtension: "json")))
        let first = try DemoContentRepository.decode(data)
        let second = try DemoContentRepository.decode(data)
        XCTAssertEqual(first.buildChallenges.map { $0.options.map(\.id) }, second.buildChallenges.map { $0.options.map(\.id) })
    }

    func testCatchesDuplicateEmptyAndInvalidReferences() {
        let word = VocabularyItem(id: "w", term: "word", meaningVi: "", example: "A word.")
        let challenge = BuildChallenge(
            id: "c", wordID: "missing", context: "ctx", prompt: "No blank here",
            options: [WordOption(id: "o", text: "word"), WordOption(id: "o", text: "x")],
            acceptedOptionIDs: ["nope"], explanations: [:]
        )
        let content = DemoContent(
            seed: 1,
            words: [word, word],
            buildChallenges: [challenge],
            recallPrompts: [RecallPrompt(id: "r", wordID: "w", sentence: "A ___.")]
        )

        let issues = ContentValidator.validate(content)
        XCTAssertTrue(issues.contains(.duplicateID(kind: "word", id: "w")))
        XCTAssertTrue(issues.contains(.emptyText(field: "meaningVi", id: "w")))
        XCTAssertTrue(issues.contains(.unknownWordID(referencedBy: "c", wordID: "missing")))
        XCTAssertTrue(issues.contains(.invalidAcceptedOption(challengeID: "c", optionID: "nope")))
        XCTAssertTrue(issues.contains(.duplicateID(kind: "option", id: "o")))
        XCTAssertTrue(issues.contains(.missingBlank(id: "c")))
        XCTAssertTrue(issues.contains(.optionCount(challengeID: "c", count: 2)))
        XCTAssertTrue(issues.contains(.wordWithoutBuild(wordID: "w")))
    }

    func testInvalidContentFailsToDecode() {
        let json = #"{"words":[],"buildChallenges":[{"id":"c","wordID":"x","context":"","prompt":"___","options":[],"acceptedOptionIDs":[],"explanations":{}}],"recallPrompts":[]}"#
        XCTAssertThrowsError(try DemoContentRepository.decode(Data(json.utf8)))
    }
}
