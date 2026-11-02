import XCTest
@testable import VocabFlow

final class CustomWordDomainTests: XCTestCase {
    private func decode(_ json: String) throws -> CustomWordLookup {
        try APIClient.decoder.decode(CustomWordLookup.self, from: Data(json.utf8))
    }

    private let sense = DraftSense(
        partOfSpeech: "noun", ipa: "/x/", cefrLevel: "C1", meaningText: "tình cờ", definitionText: "định nghĩa",
        examples: [CustomWordExample(text: "Pure serendipity.", translation: "Tình cờ.", targetLocator: TargetLocator(start: 5, end: 16))]
    )

    func testDecodesEveryLookupResultAndStatus() throws {
        let existing = try decode(#"""
        {"result":"existing","wordId":"w","lemma":"bank","meanings":[
          {"meaningId":"a","status":"available","partOfSpeech":"noun","inRoadmap":false,"ipa":"/bæŋk/","meaningText":"bờ","definitionText":"d"},
          {"meaningId":"b","status":"translation_draft","partOfSpeech":"verb","inRoadmap":false,"draftId":"t","meaningText":"m","definitionText":"d"},
          {"meaningId":"c","status":"unavailable","partOfSpeech":"noun","inRoadmap":false}
        ]}
        """#)
        guard case .existing(let word) = existing else { return XCTFail("Expected existing") }
        XCTAssertEqual(word.meanings.map(\.addition), [.meaning("a"), .translation(draftID: "t"), nil])
        XCTAssertEqual(word.meanings.map(\.ipa), ["/bæŋk/", nil, nil])

        let draft = #"{"draftId":"d","lemma":"l","senses":[]}"#
        XCTAssertEqual(try decode(#"{"result":"draft","draftId":"d","lemma":"l","senses":[]}"#), .draft(try APIClient.decoder.decode(WordDraft.self, from: Data(draft.utf8))))
        guard case .newMeaningDraft = try decode(#"{"result":"new_meaning_draft","draftId":"d","lemma":"l","senses":[]}"#) else {
            return XCTFail("Expected a private draft")
        }
        XCTAssertEqual(try decode(#"{"result":"invalid"}"#), .invalid)
        XCTAssertThrowsError(try decode(#"{"result":"new_kind"}"#))
    }

    func testLearnedOrOnPathMeaningsCannotBeAddedAgain() throws {
        let existing = try decode(#"""
        {"result":"existing","wordId":"w","lemma":"bank","meanings":[
          {"meaningId":"a","status":"available","partOfSpeech":"noun","inRoadmap":false,"learned":true,"meaningText":"bờ"},
          {"meaningId":"b","status":"available","partOfSpeech":"noun","inRoadmap":true,"learned":false,"meaningText":"bờ"},
          {"meaningId":"c","status":"available","partOfSpeech":"noun","inRoadmap":false,"meaningText":"bờ"}
        ]}
        """#)
        guard case .existing(let word) = existing else { return XCTFail("Expected existing") }
        XCTAssertEqual(word.meanings.map(\.standing), [.learned, .onPath, nil])
        XCTAssertEqual(word.meanings.map(\.canBeAdded), [false, false, true])
    }

    func testAdditionBodiesHoldOnlyOneForm() throws {
        XCTAssertEqual(try PracticeFixtures.json(CustomWordAddition.meaning("m")) as? [String: String], ["meaningId": "m"])
        XCTAssertEqual(try PracticeFixtures.json(CustomWordAddition.translation(draftID: "t")) as? [String: String], ["draftId": "t"])
        let body = try XCTUnwrap(PracticeFixtures.json(CustomWordAddition.draft("d", senseIndex: 1, edits: nil)) as? [String: Any])
        XCTAssertEqual(Set(body.keys), ["draftId", "senseIndex"])
    }

    func testInputRules() {
        XCTAssertNil(CustomWordInput.issue(in: "  mother-in-law "))
        XCTAssertNil(CustomWordInput.issue(in: "don’t"))
        XCTAssertEqual(CustomWordInput.issue(in: "   "), .empty)
        XCTAssertEqual(CustomWordInput.issue(in: "-word"), .invalidCharacters)
        XCTAssertEqual(CustomWordInput.issue(in: "word2"), .invalidCharacters)
        XCTAssertEqual(CustomWordInput.issue(in: String(repeating: "a", count: 65)), .tooLong)
    }

    func testLocatorCountsUTF16Units() throws {
        let sentence = "😀 Serendipity!"
        let locator = try XCTUnwrap(TargetLocator(locating: "serendipity", in: sentence))
        XCTAssertEqual(locator, TargetLocator(start: 3, end: 14))
        XCTAssertEqual(locator.substring(of: sentence), "Serendipity")
        XCTAssertNil(TargetLocator(start: 3, end: 99).substring(of: sentence))
    }

    func testNoEditsMeansNothingToSend() {
        var draft = CustomWordEditDraft(lemma: "serendipity", sense: sense)
        XCTAssertNil(draft.edits)
        draft.meaningText = " tình cờ "
        XCTAssertNil(draft.edits, "Whitespace isn't an edit")
    }

    func testOnlyChangedFieldsAreSent() {
        var draft = CustomWordEditDraft(lemma: "serendipity", sense: sense)
        draft.meaningText = "may mắn"
        XCTAssertEqual(draft.edits, CustomWordEdits(meaningText: "may mắn"))
    }

    func testRewrittenSentenceMovesTheHighlight() {
        var draft = CustomWordEditDraft(lemma: "serendipity", sense: sense)
        draft.examples[0].text = "  What a serendipity!  "
        XCTAssertTrue(draft.isValid)
        XCTAssertEqual(draft.edits?.examples, [
            CustomWordExample(text: "What a serendipity!", translation: "Tình cờ.", targetLocator: TargetLocator(start: 7, end: 18)),
        ])
    }

    func testInflectedSentenceNeedsAPickedWord() throws {
        var draft = CustomWordEditDraft(lemma: "run", sense: sense)
        draft.examples[0].text = "She ran home."
        XCTAssertFalse(draft.isValid, "Nothing to highlight yet")

        let ran = try XCTUnwrap(TargetLocator.words(in: "She ran home.").dropFirst().first)
        draft.pick(ran, inExample: 0)
        XCTAssertTrue(draft.isValid)
        XCTAssertEqual(draft.edits?.examples?.first?.targetLocator, TargetLocator(start: 4, end: 7))
    }

    func testPickedHighlightLastsOnlyForItsSentence() {
        var draft = CustomWordEditDraft(lemma: "run", sense: sense)
        draft.examples[0].text = "She ran home."
        draft.pick(TargetLocator(start: 4, end: 7), inExample: 0)
        draft.examples[0].text = "She ran away."
        XCTAssertNil(draft.locator(for: draft.examples[0]))
    }

    func testSecondWordExtendsTheHighlightAndAThirdStartsOver() {
        var draft = CustomWordEditDraft(lemma: "run", sense: sense)
        draft.examples[0].text = "She ran home."
        draft.pick(TargetLocator(start: 0, end: 3), inExample: 0)
        draft.pick(TargetLocator(start: 4, end: 7), inExample: 0)
        XCTAssertEqual(draft.locator(for: draft.examples[0]), TargetLocator(start: 0, end: 7))
        draft.pick(TargetLocator(start: 8, end: 12), inExample: 0)
        XCTAssertEqual(draft.locator(for: draft.examples[0]), TargetLocator(start: 8, end: 12))
    }

    func testWordsSkipPunctuation() {
        let sentence = "Hi, there!"
        XCTAssertEqual(TargetLocator.words(in: sentence).compactMap { $0.substring(of: sentence) }, ["Hi", "there"])
    }

    func testEditingAnOverriddenWordSendsOnlyWhatChanged() {
        var draft = CustomWordEditDraft(word: CustomWordFixtures.word(overridden: true))
        draft.meaningText = "mới"
        XCTAssertEqual(draft.edits, CustomWordEdits(meaningText: "mới"), "The backend merges by field")
    }

    func testAnyExampleEditSendsTheWholeList() {
        let extra = CustomWordExample(text: "A bank.", translation: "Bờ.", targetLocator: TargetLocator(start: 2, end: 6))
        var draft = CustomWordEditDraft(word: CustomWordFixtures.word(examples: [extra, extra]))
        draft.examples[1].translation = "Một bờ."
        XCTAssertEqual(draft.edits?.examples?.map(\.translation), ["Bờ.", "Một bờ."])
    }

    func testExistingMeaningCarriesEdits() throws {
        let meaning = ExistingMeaning(
            meaningId: "m", status: .available, partOfSpeech: "noun", inRoadmap: false, draftId: nil, ipa: nil,
            meaningText: "bờ", definitionText: "d", examples: nil
        )
        var draft = CustomWordEditDraft(lemma: "bank", meaning: meaning)
        draft.meaningText = "bờ sông"
        var addition = try XCTUnwrap(meaning.addition)
        addition.edits = draft.edits
        let body = try XCTUnwrap(PracticeFixtures.json(addition) as? [String: Any])
        XCTAssertEqual(Set(body.keys), ["meaningId", "edits"])
    }
}

enum CustomWordFixtures {
    static func word(id: String = "m", overridden: Bool = false, examples: [CustomWordExample]? = nil) -> CustomWord {
        CustomWord(
            meaningId: id, wordId: "w", lemma: "bank", partOfSpeech: "noun", meaningText: "bờ", definitionText: "định nghĩa",
            examples: examples, audioUrl: nil, overridden: overridden, translationPending: false, recalled: false
        )
    }

    static func error(_ status: Int, _ code: String, retryable: Bool = false) -> APIError {
        .server(status: status, code: code, message: "m", retryable: retryable, requestID: nil)
    }
}

@MainActor
final class CustomWordStoreTests: XCTestCase {
    private var api: StubVocabAPI!
    private var store: CustomWordStore!

    override func setUp() async throws {
        api = StubVocabAPI()
        store = CustomWordStore(api: api, audio: SilentAudioClips())
    }

    private let draft = CustomWordLookup.draft(WordDraft(draftId: "d", lemma: "l", senses: []))

    func testLookupIsTrimmedAndShowsTheResult() async {
        api.lookupResults = [.success(.invalid)]
        await store.lookup("  word ")
        XCTAssertEqual(api.lookups, [CustomWordQuery(text: "word")])
        XCTAssertEqual(store.phase, .result(.invalid))
    }

    func testProviderOutageOffersRetryAndLimitDoesNot() async {
        api.lookupResults = [
            .failure(CustomWordFixtures.error(503, "LEXICAL_PROVIDER_UNAVAILABLE", retryable: true)),
            .failure(CustomWordFixtures.error(429, "CUSTOM_WORD_LIMIT_REACHED")),
        ]
        await store.lookup("word")
        guard case .failed(_, canRetry: true) = store.phase else { return XCTFail("Expected a retry") }
        await store.retryLookup()
        guard case .failed(_, canRetry: false) = store.phase else { return XCTFail("Expected no retry") }
        XCTAssertEqual(api.lookups.count, 2)
    }

    func testAddRefreshesHomeAndAcceptsExistingWord() async {
        var refreshes = 0
        store.onRoadmapChanged = { refreshes += 1 }
        api.addResults = [.success(CustomWordAdded(meaningId: "m", added: false))]
        await store.add(.meaning("m"), lemma: "bank")
        XCTAssertEqual(store.phase, .added(lemma: "bank", isNew: false))
        XCTAssertEqual(refreshes, 1)
    }

    func testStaleDraftRepeatsTheLookupSilently() async {
        for code in [(409, "WORD_ALREADY_EXISTS"), (422, "CUSTOM_WORD_INVALID")] {
            api.lookupResults = [.success(draft), .success(.invalid)]
            api.addResults = [.failure(CustomWordFixtures.error(code.0, code.1))]
            await store.lookup("word", context: "river")
            await store.add(.draft("d", senseIndex: 0, edits: nil), lemma: "word")
            XCTAssertEqual(api.lookups.suffix(2).map(\.context), ["river", "river"])
            XCTAssertEqual(store.phase, .result(.invalid))
            XCTAssertNil(store.notice)
        }
    }

    func testUnavailableMeaningRefreshesStatusAndSaysSo() async {
        api.lookupResults = [.success(draft), .success(.invalid)]
        api.addResults = [.failure(CustomWordFixtures.error(422, "CUSTOM_WORD_UNAVAILABLE"))]
        await store.lookup("word")
        await store.add(.meaning("m"), lemma: "word")
        XCTAssertEqual(api.lookups.count, 2)
        XCTAssertNotNil(store.notice)
    }

    func testOtherAddFailuresKeepTheResult() async {
        api.lookupResults = [.success(draft)]
        api.addResults = [.failure(CustomWordFixtures.error(429, "CUSTOM_WORD_LIMIT_REACHED"))]
        await store.lookup("word")
        await store.add(.draft("d", senseIndex: 0, edits: nil), lemma: "word")
        XCTAssertEqual(store.phase, .result(draft))
        XCTAssertEqual(api.lookups.count, 1, "The limit is never retried automatically")
        XCTAssertNotNil(store.notice)
    }

    func testAnswerForAClosedSheetIsDropped() async {
        api.lookupResults = [.success(.invalid)]
        api.onLookup = { [store] in await store?.resetLookup() }
        await store.lookup("word")
        XCTAssertEqual(store.phase, .idle)
    }

    func testGoingBackFromAnOtherMeaningSearchReturnsToTheWord() async {
        let word = ExistingWord(wordId: "w", lemma: "arrive", meanings: [])
        api.lookupResults = [.success(.existing(word)), .success(.newMeaningDraft(WordDraft(draftId: "d", lemma: "arrive", senses: [])))]
        await store.lookup("arrived")
        await store.lookup("arrive", context: "at a decision")
        XCTAssertEqual(store.lastContext, "at a decision")

        store.goBack()
        XCTAssertEqual(store.phase, .result(.existing(word)))
        XCTAssertEqual(api.lookups.count, 2, "Going back doesn't look the word up again")

        store.goBack()
        XCTAssertEqual(store.phase, .idle)
    }

    func testFailedOtherMeaningSearchKeepsItsContextAndWord() async {
        let word = ExistingWord(wordId: "w", lemma: "arrive", meanings: [])
        api.lookupResults = [.success(.existing(word)), .failure(CustomWordFixtures.error(503, "LEXICAL_PROVIDER_UNAVAILABLE", retryable: true))]
        await store.lookup("arrive")
        await store.lookup("arrive", context: "at a decision")
        XCTAssertEqual(store.baseWord, word)
        XCTAssertEqual(store.lastContext, "at a decision")
    }

    func testChangesReloadTheList() async {
        let word = CustomWordFixtures.word()
        api.customWordList = [word]
        await store.loadWords()
        api.customWordList = []
        await store.remove(word)
        XCTAssertEqual(api.removed, ["m"])
        XCTAssertTrue(store.words.isEmpty)
    }

    func testRemovingAWordAlreadyGoneIsNotAnError() async {
        api.customWordList = [CustomWordFixtures.word()]
        await store.loadWords()
        api.customWordList = []
        api.removeError = CustomWordFixtures.error(404, "NOT_FOUND")
        await store.remove(CustomWordFixtures.word())
        XCTAssertNil(store.listError)
        XCTAssertTrue(store.words.isEmpty)
    }

    func testFailedChangeKeepsTheList() async {
        api.customWordList = [CustomWordFixtures.word()]
        await store.loadWords()
        api.removeError = .transport
        await store.remove(CustomWordFixtures.word())
        XCTAssertNotNil(store.listError)
        XCTAssertEqual(store.words.count, 1)
    }
}
