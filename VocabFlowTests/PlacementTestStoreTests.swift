import XCTest
@testable import VocabFlow

@MainActor
final class PlacementTestStoreTests: XCTestCase {
    private let api = StubVocabAPI()
    private let result = PlacementResult(proficiencyLevel: .b1, correctCount: 1, totalCount: 2)

    private func question(_ id: String) -> PlacementQuestion {
        PlacementQuestion(
            id: id,
            prompt: .init(text: "word-\(id)"),
            question: "?",
            options: [.init(id: "\(id)-a", text: "a"), .init(id: "\(id)-b", text: "b")]
        )
    }

    private func makeStore() -> PlacementTestStore {
        PlacementTestStore(api: api, haptics: NoOpFeedback())
    }

    private func answerAll(_ store: PlacementTestStore) async {
        store.select("q1-b")
        await store.confirmAnswer()
        await store.skipQuestion()
    }

    private func startedStore() async -> PlacementTestStore {
        api.placementQuestions = .success([question("q1"), question("q2")])
        let store = makeStore()
        await store.start().value
        return store
    }

    func testDecodesQuestionsWithStringOptionIDsAndNoAnswerKey() throws {
        let json = """
        {"id":"q1","template":"select","variant":"gloss","prompt":{"type":"text","text":"clarify"},
         "question":"Từ này có nghĩa là gì?","options":[{"id":"0190-a","text":"làm rõ"},{"id":"0190-b","text":"x"}]}
        """
        let question = try APIClient.decoder.decode(PlacementQuestion.self, from: Data(json.utf8))
        XCTAssertEqual(question.prompt.text, "clarify")
        XCTAssertEqual(question.options.map(\.id), ["0190-a", "0190-b"])
    }

    func testASkippedQuestionIsSentAsAnExplicitNull() throws {
        let answer = try PracticeFixtures.json(PlacementAnswer(questionId: "q1", optionId: nil)) as? [String: Any]
        XCTAssertEqual(answer?["questionId"] as? String, "q1")
        XCTAssertTrue(answer?["optionId"] is NSNull)
    }

    func testStartShowsLoadingRightAway() {
        let store = makeStore()
        store.start()
        XCTAssertEqual(store.stage, .loading)
    }

    func testKeepsQuestionOrder() async {
        api.placementQuestions = .success([question("q2"), question("q1")])
        let store = makeStore()
        await store.start().value
        XCTAssertEqual(store.stage, .answering)
        XCTAssertEqual(store.questions.map(\.id), ["q2", "q1"])
        XCTAssertEqual(store.currentQuestion?.id, "q2")
    }

    func testNoQuestionsMeansNoContent() async {
        let store = makeStore()
        await store.start().value
        XCTAssertEqual(store.stage, .noContent)
    }

    func testLoadFailureIsReported() async {
        api.placementQuestions = .failure(.transport)
        let store = makeStore()
        await store.start().value
        XCTAssertEqual(store.stage, .loadFailed(APIError.transport.userMessage))
    }

    func testCannotConfirmWithoutAChoice() async {
        let store = await startedStore()
        await store.confirmAnswer()
        XCTAssertEqual(store.index, 0)
        XCTAssertEqual(store.stage, .answering)
    }

    func testASecondConfirmDoesNotAnswerTheNextQuestion() async {
        let store = await startedStore()
        store.select("q1-a")
        await store.confirmAnswer()
        await store.confirmAnswer()
        XCTAssertEqual(store.index, 1)
        XCTAssertNil(store.selectedOptionID)
    }

    func testSkippingDiscardsTheSelection() async {
        api.placementResults = [.success(result)]
        let store = await startedStore()
        store.select("q1-a")
        await store.skipQuestion()
        XCTAssertEqual(store.index, 1)
        XCTAssertNil(store.selectedOptionID)
        await store.skipQuestion()
        XCTAssertEqual(api.placementSubmissions.first, [
            PlacementAnswer(questionId: "q1", optionId: nil),
            PlacementAnswer(questionId: "q2", optionId: nil),
        ])
    }

    func testSubmitsEveryQuestionInOrderOnce() async {
        api.placementResults = [.success(result)]
        let store = await startedStore()
        await answerAll(store)
        XCTAssertEqual(api.placementSubmissions, [[
            PlacementAnswer(questionId: "q1", optionId: "q1-b"),
            PlacementAnswer(questionId: "q2", optionId: nil),
        ]])
        XCTAssertEqual(store.stage, .finished(result))
    }

    func testFinishingTellsTheAppALevelWasSaved() async {
        api.placementResults = [.success(result)]
        let store = await startedStore()
        var notified = false
        store.onPlaced = { notified = true }
        await answerAll(store)
        XCTAssertTrue(notified)
    }

    func testARetriedSubmitResendsTheSameAnswers() async {
        api.placementResults = [.failure(.transport), .success(result)]
        let store = await startedStore()
        await answerAll(store)
        XCTAssertEqual(store.stage, .submitFailed(APIError.transport.userMessage, canRetry: true))
        await store.retrySubmit()
        XCTAssertEqual(store.stage, .finished(result))
        XCTAssertEqual(api.placementSubmissions.count, 2)
        XCTAssertEqual(api.placementSubmissions[0], api.placementSubmissions[1])
    }

    func testARejectedSubmitCannotBeRetried() async {
        let rejected = APIError.server(status: 400, code: "VALIDATION_FAILED", message: "No valid question", retryable: false, requestID: nil)
        api.placementResults = [.failure(rejected)]
        let store = await startedStore()
        await answerAll(store)
        XCTAssertEqual(store.stage, .submitFailed("No valid question", canRetry: false))
        await store.retrySubmit()
        XCTAssertEqual(api.placementSubmissions.count, 1)
    }

    func testRetakingStartsFresh() async {
        api.placementResults = [.success(result), .success(result)]
        let store = await startedStore()
        await answerAll(store)
        await store.start().value
        XCTAssertEqual(store.stage, .answering)
        XCTAssertEqual(store.index, 0)
        await answerAll(store)
        XCTAssertEqual(api.placementSubmissions[1].count, 2, "The first run's answers are gone")
    }

    func testAnAnswerForACancelledTestIsIgnored() async {
        api.placementQuestions = .success([question("q1")])
        let store = makeStore()
        let release = AsyncStream<Void>.makeStream()
        api.onPlacementTest = {
            for await _ in release.stream { break }
        }
        let load = store.start()
        store.cancel()
        release.continuation.yield()
        await load.value
        XCTAssertEqual(store.stage, .loading)
        XCTAssertTrue(store.questions.isEmpty)
    }
}
