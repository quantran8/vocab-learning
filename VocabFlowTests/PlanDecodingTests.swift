import XCTest
@testable import VocabFlow

final class PlanDecodingTests: XCTestCase {
    private func decodePlan(_ steps: String) throws -> SessionPlan {
        let json = #"{"sessionId":"s1","mode":"daily","expiresAt":"2026-11-03T10:00:00.000Z","steps":[\#(steps)]}"#
        return try APIClient.decoder.decode(SessionPlan.self, from: Data(json.utf8))
    }

    private func decodeTask(_ body: String) throws -> PracticeTask {
        let plan = try decodePlan(#"{"type":"practice","phase":"new_practice","task":{"id":"t1",\#(body)}}"#)
        guard case .practice(_, let task) = plan.steps.first else { throw APIError.invalidResponse }
        return task
    }

    func testEmptyPlanHasNoSession() throws {
        let json = #"{"sessionId":null,"mode":"daily","steps":[]}"#
        let plan = try APIClient.decoder.decode(SessionPlan.self, from: Data(json.utf8))
        XCTAssertNil(plan.sessionID)
        XCTAssertTrue(plan.steps.isEmpty)
    }

    func testDecodesLearnStep() throws {
        let plan = try decodePlan(#"""
        {"type":"learn","id":"l1","card":{"word":"clarify","meaning":"làm rõ","definition":"d",
         "audio":{"url":"https://a.example/x.mp3","locale":"en-US"},"examples":[{"text":"t","translation":"u"}]}}
        """#)
        guard case .learn(let id, let card) = plan.steps[0] else { return XCTFail("Not a learn step") }
        XCTAssertEqual(id, "l1")
        XCTAssertEqual(card.word, "clarify")
        XCTAssertNil(card.ipa)
        XCTAssertEqual(card.audio?.locale, "en-US")
    }

    func testDecodesEveryTemplate() throws {
        let text = #""prompt":{"type":"text","text":"x"}"#
        let select = try decodeTask(#""template":"select","variant":"gloss",\#(text),"question":"q","options":[{"id":1,"text":"a"},{"id":2,"text":"b"}],"evaluation":{"correctOptionId":2}"#)
        XCTAssertEqual(select.body, .choice(options: [TaskOption(id: 1, text: "a"), TaskOption(id: 2, text: "b")], sentence: nil, correctOptionID: 2))

        let cloze = try decodeTask(#""template":"cloze_select","variant":"single_blank",\#(text),"sentenceParts":{"before":"a ","after":" b"},"options":[{"id":1,"text":"a"}],"evaluation":{"correctOptionId":1}"#)
        XCTAssertEqual(cloze.body, .choice(options: [TaskOption(id: 1, text: "a")], sentence: SentenceParts(before: "a ", after: " b"), correctOptionID: 1))

        let typing = try decodeTask(#""template":"typing","variant":"meaning_recall",\#(text),"evaluation":{"acceptedResponses":["a"]}"#)
        XCTAssertEqual(typing.body, .typing(accepted: ["a"]))

        let reorder = try decodeTask(#""template":"fly_reorder","variant":"spelling_recall",\#(text),"tiles":[{"id":1,"text":"a"}],"evaluation":{"acceptedResponses":["a"]}"#)
        XCTAssertEqual(reorder.body, .reorder(tiles: [TaskOption(id: 1, text: "a")], accepted: ["a"]))

        let match = try decodeTask(#""template":"match","variant":"meaning_pairs",\#(text),"pairs":{"left":[{"id":1,"text":"a"}],"right":[{"id":5,"text":"b"}]},"evaluation":{"correctPairs":[{"leftId":1,"rightId":5}]}"#)
        XCTAssertEqual(match.body, .match(left: [TaskOption(id: 1, text: "a")], right: [TaskOption(id: 5, text: "b")], correct: [PairKey(leftId: 1, rightId: 5)]))

        let surgery = try decodeTask(#""template":"surgery","variant":"fix_spelling",\#(text),"word":"ab","evaluation":{"wrongGraphemeIndex":1,"replacement":""}"#)
        XCTAssertEqual(surgery.body, .surgery(word: "ab", wrongGraphemeIndex: 1, replacement: ""))

        let recording = try decodeTask(#""template":"recording","variant":"scripted_pronunciation","prompt":{"type":"audio","audio":{"url":"https://a.example/x.mp3","locale":"en-US"}},"assessment":{"kind":"azurePronunciation"}"#)
        XCTAssertEqual(recording.body, .recording)
        XCTAssertEqual(recording.prompt?.isAudio, true)
    }

    func testMaxRetriesIsOptional() throws {
        let body = #""template":"typing","variant":"meaning_recall","prompt":{"type":"text","text":"x"},"evaluation":{"acceptedResponses":["a"]}"#
        XCTAssertEqual(try decodeTask(body + #","maxRetries":2"#).maxRetries, 2)
        XCTAssertNil(try decodeTask(body).maxRetries, "Sessions issued before the limit stay unlimited")
    }

    func testOnlyClozeMayComeWithoutAPrompt() throws {
        let cloze = try decodeTask(#""template":"cloze_select","variant":"single_blank","sentenceParts":{"before":"a ","after":" b"},"options":[{"id":1,"text":"a"}],"evaluation":{"correctOptionId":1}"#)
        XCTAssertNil(cloze.prompt)
        XCTAssertNil(TaskAttempt(task: cloze, phase: .dueReview).deliveryMode)
        XCTAssertThrowsError(try decodeTask(#""template":"typing","variant":"meaning_recall","evaluation":{"acceptedResponses":["a"]}"#))
    }

    func testPromptHighlightDecodesAndSplits() throws {
        let task = try decodeTask(#""template":"typing","variant":"meaning_recall","prompt":{"type":"text","text":"Sign the contract.","highlight":{"start":9,"end":17}},"evaluation":{"acceptedResponses":["a"]}"#)
        guard case .text(let text, let highlight?)? = task.prompt else { return XCTFail("No highlight") }
        let parts = highlight.split(text)
        XCTAssertEqual(parts?.before, "Sign the ")
        XCTAssertEqual(parts?.word, "contract")
        XCTAssertEqual(parts?.after, ".")
    }

    func testPromptHighlightCountsUTF16Units() {
        XCTAssertEqual(PromptHighlight(start: 3, end: 6).split("👍 pay")?.word, "pay")
    }

    func testPromptHighlightOutsideTheTextIsIgnored() {
        XCTAssertNil(PromptHighlight(start: 2, end: 9).split("short"))
        XCTAssertNil(PromptHighlight(start: 2, end: 2).split("short"))
    }

    func testClozeNeedsItsSentence() {
        XCTAssertThrowsError(try decodeTask(#""template":"cloze_select","variant":"single_blank","options":[{"id":1,"text":"a"}],"evaluation":{"correctOptionId":1}"#))
    }

    func testClozeLineKeepsPunctuationOnTheBlank() {
        let line = ClozeLine(SentenceParts(before: "See the ", after: ". Then pay"))
        XCTAssertEqual(line.wordsBefore, ["See", "the"])
        XCTAssertEqual(line.attachedBefore, "")
        XCTAssertEqual(line.attachedAfter, ".")
        XCTAssertEqual(line.wordsAfter, ["Then", "pay"])
    }

    func testClozeLineHandlesABlankAtEitherEnd() {
        let line = ClozeLine(SentenceParts(before: "", after: " is late"))
        XCTAssertEqual(line.wordsBefore, [])
        XCTAssertEqual(line.attachedAfter, "")
        XCTAssertEqual(line.wordsAfter, ["is", "late"])
        XCTAssertEqual(ClozeLine(SentenceParts(before: "Pay the", after: "")).attachedBefore, "the")
    }

    func testUnknownTemplateFailsThePlan() {
        XCTAssertThrowsError(try decodeTask(#""template":"hologram","variant":"gloss","prompt":{"type":"text","text":"x"}"#))
    }

    func testUnknownVariantFailsThePlan() {
        XCTAssertThrowsError(try decodeTask(#""template":"typing","variant":"gloss","prompt":{"type":"text","text":"x"},"evaluation":{"acceptedResponses":["a"]}"#))
    }

    func testMissingAnswerKeyFailsThePlan() {
        XCTAssertThrowsError(try decodeTask(#""template":"typing","variant":"meaning_recall","prompt":{"type":"text","text":"x"},"evaluation":{}"#))
    }

    func testUnknownPhaseIsOnlyALabel() throws {
        let plan = try decodePlan(#"{"type":"practice","phase":"somethingNew","task":{"id":"t1","template":"recording","variant":"scripted_pronunciation","prompt":{"type":"text","text":"x"}}}"#)
        guard case .practice(let phase, _) = plan.steps[0] else { return XCTFail("Not a practice step") }
        XCTAssertEqual(phase, .other)
    }

    func testNewPracticePhaseIsRecognized() throws {
        let plan = try decodePlan(#"{"type":"practice","phase":"new_practice","task":{"id":"t1","template":"recording","variant":"scripted_pronunciation","prompt":{"type":"text","text":"x"}}}"#)
        guard case .practice(let phase, _) = plan.steps[0] else { return XCTFail("Not a practice step") }
        XCTAssertEqual(phase, .newPractice)
    }

    func testSessionModesUseWireValues() throws {
        let capabilities = PlanRequest.Capabilities(audioPlayback: true, microphone: true)
        let body = try JSONEncoder().encode(PlanRequest(mode: .weakWordsPractice, capabilities: capabilities))
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
        XCTAssertEqual(json["mode"] as? String, "weak_words_practice")

        let plan = try APIClient.decoder.decode(SessionPlan.self, from: Data(#"{"sessionId":null,"mode":"checkpoint_challenge","steps":[]}"#.utf8))
        XCTAssertEqual(plan.mode, .checkpointChallenge)
    }

    func testLearnHomeReportsCheckpointProgress() throws {
        let json = #"{"dueCount":0,"checkpointAvailable":0,"checkpointSessionsDone":3,"checkpointSessionsRequired":7,"learnedTotal":15}"#
        let home = try APIClient.decoder.decode(LearnHome.self, from: Data(json.utf8))
        XCTAssertEqual(home.checkpointSessionsDone, 3)
        XCTAssertEqual(home.checkpointProgress, 3.0 / 7.0, accuracy: 0.0001)
    }

    func testCheckpointProgressStaysWithinRange() {
        let full = LearnHome(dueCount: 0, checkpointAvailable: 0, checkpointSessionsDone: 9, checkpointSessionsRequired: 7, learnedTotal: 0)
        XCTAssertEqual(full.checkpointProgress, 1)
        let unset = LearnHome(dueCount: 0, checkpointAvailable: 0, checkpointSessionsDone: 0, checkpointSessionsRequired: 0, learnedTotal: 0)
        XCTAssertEqual(unset.checkpointProgress, 0)
    }

    func testDecodesWordsResponseShape() throws {
        let json = #"""
        {"wordId":"w","lemma":"clarify","needsPractice":true,"fullyVerified":false,"meanings":[{
         "meaning":{"partOfSpeech":"verb","text":"làm rõ"},"learnedAt":"2026-10-30T10:00:00.000Z","nextReviewAt":"2026-10-31T10:00:00Z",
         "needsPractice":true,"skills":{"reading":{"status":"verified","needsPractice":false},
         "writing":{"status":"not_verified","needsPractice":true}}}]}
        """#
        let word = try APIClient.decoder.decode(WordProgress.self, from: Data(json.utf8))
        XCTAssertNil(word.meanings[0].skills.listening)
        XCTAssertEqual(word.meanings[0].skills.reading.status, .verified)
        XCTAssertEqual(word.meanings[0].skills.writing.status, .notVerified)
        XCTAssertTrue(word.matches("LAM RO"))
    }
}
