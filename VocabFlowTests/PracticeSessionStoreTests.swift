import XCTest
@testable import VocabFlow

@MainActor
final class PracticeSessionStoreTests: XCTestCase {
    private let summary = CommitSummary(newWordGoalSlots: 1, reviewedMeanings: 0, practiceTasks: 2)
    private lazy var committed = CommitResponse(sessionId: "s1", summary: summary)
    private let api = StubVocabAPI()
    private let recorder = StubRecorder()

    private func makeStore(steps: [PlanStep]) -> PracticeSessionStore {
        api.plan = .success(SessionPlan(sessionID: "s1", mode: .daily, steps: steps))
        return PracticeSessionStore(api: api, audio: SilentAudioClips(), recorder: recorder, haptics: NoOpFeedback())
    }

    private func waitForStage(_ store: PracticeSessionStore, where matches: (PracticeSessionStore.Stage) -> Bool) async {
        for _ in 0..<1000 where !matches(store.stage) {
            await Task.yield()
        }
    }

    private func runToCommit(_ store: PracticeSessionStore) async {
        await store.start(.daily)
        store.advance()
        store.submitOption(3)
        store.advance()
        await waitForStage(store) { $0 != .running && $0 != .committing }
    }

    private let learnAndChoice: [PlanStep] = [
        .learn(id: "l1", card: PracticeFixtures.card),
        .practice(phase: .newPractice, task: PracticeFixtures.choice()),
    ]

    func testEmptyPlanHasNoSession() async {
        let store = makeStore(steps: [])
        api.plan = .success(SessionPlan(sessionID: nil, mode: .daily, steps: []))
        await store.start(.daily)
        XCTAssertEqual(store.stage, .empty)
    }

    func testMissingCheckpointChallengeIsEmptyNotAnError() async {
        let store = makeStore(steps: [])
        api.plan = .failure(.server(status: 404, code: "NOT_FOUND", message: "", retryable: false, requestID: nil))
        await store.start(.checkpointChallenge)
        XCTAssertEqual(store.stage, .empty)
    }

    func testCapabilitiesReflectTheDevice() async {
        let store = makeStore(steps: learnAndChoice)
        recorder.canRecord = false
        await store.start(.checkpointChallenge, challengeID: "c1")
        let request = api.planRequests.first
        XCTAssertEqual(request?.capabilities, PlanRequest.Capabilities(audioPlayback: false, microphone: false))
        XCTAssertEqual(request?.challengeId, "c1")
    }

    func testCannotAdvancePastAnUnfinishedTask() async {
        let store = makeStore(steps: [.practice(phase: .dueReview, task: PracticeFixtures.choice())])
        await store.start(.daily)
        store.advance()
        XCTAssertEqual(store.stepIndex, 0)
        XCTAssertEqual(store.stage, .running)
    }

    func testCommitIncludesLearnStepsAndEveryTask() async throws {
        let store = makeStore(steps: learnAndChoice)
        api.commitResults = [.success(committed)]
        await runToCommit(store)

        XCTAssertEqual(store.stage, .finished(summary))
        let body = try XCTUnwrap(JSONSerialization.jsonObject(with: api.commitBodies[0]) as? [String: Any])
        XCTAssertEqual(body["learnStepsCompleted"] as? [String], ["l1"])
        let results = try XCTUnwrap(body["taskResults"] as? [[String: Any]])
        XCTAssertEqual(results.map { $0["taskId"] as? String }, ["t-choice"])
    }

    func testCommitRetryResendsTheSameBytes() async {
        let store = makeStore(steps: learnAndChoice)
        api.commitResults = [.failure(.transport), .success(committed)]
        await runToCommit(store)
        guard case .failed(.commit) = store.stage else { return XCTFail("Expected a retryable failure") }

        await store.retry()
        XCTAssertEqual(store.stage, .finished(summary))
        XCTAssertEqual(api.commitBodies.count, 2)
        XCTAssertEqual(api.commitBodies[0], api.commitBodies[1])
    }

    func testPayloadConflictAdoptsTheSavedResult() async {
        let store = makeStore(steps: learnAndChoice)
        api.commitResults = [.failure(.server(status: 409, code: "SESSION_PAYLOAD_CONFLICT", message: "", retryable: false, requestID: nil))]
        api.status = CommitStatus(status: "committed", response: committed)
        await runToCommit(store)
        XCTAssertEqual(store.stage, .finished(summary))
    }

    func testExpiredSessionCannotBeRetried() async {
        let store = makeStore(steps: learnAndChoice)
        api.commitResults = [.failure(.server(status: 410, code: "SESSION_EXPIRED", message: "", retryable: false, requestID: nil))]
        await runToCommit(store)
        guard case .failed(.sessionLost) = store.stage else { return XCTFail("Expected a lost session") }
    }

    func testPassingRecordingCommitsTheLastReceipt() async {
        let store = makeStore(steps: [.practice(phase: .newPractice, task: PracticeFixtures.recording())])
        api.commitResults = [.success(committed)]
        api.assessResult = .success(RecordingAssessment(assessmentReceiptId: "r1", validity: "valid", passed: false, accuracyScore: 50))
        await store.start(.daily)
        await store.startRecording()
        await store.stopRecording()

        api.assessResult = .success(RecordingAssessment(assessmentReceiptId: "r2", validity: "valid", passed: true, accuracyScore: 90))
        await store.startRecording()
        await store.stopRecording()
        store.acceptRecording()

        XCTAssertEqual(store.attempts["t-recording"]?.events.map(\.action), [.assessed(receiptID: "r2")])
    }

    func testRecordingStopsAtTheLimitAndKeepsTheLastReceipt() async {
        let store = makeStore(steps: [.practice(phase: .newPractice, task: PracticeFixtures.recording(maxRetries: 0))])
        api.commitResults = [.success(committed)]
        api.assessResult = .success(RecordingAssessment(assessmentReceiptId: "r1", validity: "invalid", passed: nil, accuracyScore: nil))
        await store.start(.daily)
        await store.startRecording()
        await store.stopRecording()

        await store.startRecording()
        XCTAssertNotEqual(store.recording, .recording, "A further upload would answer 422")
        store.acceptRecording()
        XCTAssertEqual(store.attempts["t-recording"]?.events.map(\.action), [.assessed(receiptID: "r1")])
    }

    func testSpeechOutageDoesNotUseATry() async {
        let store = makeStore(steps: [.practice(phase: .newPractice, task: PracticeFixtures.recording(maxRetries: 0))])
        api.assessResult = .failure(.server(status: 503, code: "SPEECH_PROVIDER_UNAVAILABLE", message: "", retryable: true, requestID: nil))
        await store.start(.daily)
        await store.startRecording()
        await store.stopRecording()
        XCTAssertEqual(store.currentAttempt?.canRecordAgain, true)
    }

    func testBackendLimitFallsBackToTheLastReceipt() async {
        let store = makeStore(steps: [.practice(phase: .newPractice, task: PracticeFixtures.recording())])
        api.commitResults = [.success(committed)]
        api.assessResult = .success(RecordingAssessment(assessmentReceiptId: "r1", validity: "valid", passed: false, accuracyScore: 50))
        await store.start(.daily)
        await store.startRecording()
        await store.stopRecording()

        api.assessResult = .failure(.server(status: 422, code: "INVALID_SUBMISSION", message: "", retryable: false, requestID: nil))
        await store.startRecording()
        await store.stopRecording()
        store.acceptRecording()
        XCTAssertEqual(store.attempts["t-recording"]?.events.map(\.action), [.assessed(receiptID: "r1")])
    }

    func testDeniedMicrophoneReportsUnavailable() async {
        let store = makeStore(steps: [.practice(phase: .newPractice, task: PracticeFixtures.recording())])
        api.commitResults = [.success(committed)]
        recorder.hasAccess = false
        await store.start(.daily)
        await store.startRecording()
        XCTAssertEqual(store.recording, .blocked(reason: "micPermissionDenied"))
        store.acceptRecording()
        XCTAssertEqual(store.attempts["t-recording"]?.events.map(\.action), [.unavailable(reason: "micPermissionDenied")])
    }

    func testSpeechOutageCanBeSkippedAsUnavailable() async {
        let store = makeStore(steps: [.practice(phase: .newPractice, task: PracticeFixtures.recording())])
        api.commitResults = [.success(committed)]
        api.assessResult = .failure(.server(status: 503, code: "SPEECH_PROVIDER_UNAVAILABLE", message: "", retryable: true, requestID: nil))
        await store.start(.daily)
        await store.startRecording()
        await store.stopRecording()
        XCTAssertEqual(store.recording, .uploadFailed)
        store.acceptRecording()
        XCTAssertEqual(store.attempts["t-recording"]?.events.map(\.action), [.unavailable(reason: "speechProviderUnavailable")])
    }

    func testAssessOnAnExpiredSessionEndsIt() async {
        let store = makeStore(steps: [.practice(phase: .newPractice, task: PracticeFixtures.recording())])
        api.assessResult = .failure(.server(status: 410, code: "SESSION_EXPIRED", message: "", retryable: false, requestID: nil))
        await store.start(.daily)
        await store.startRecording()
        await store.stopRecording()
        guard case .failed(.sessionLost) = store.stage else { return XCTFail("Expected a lost session") }
    }

    func testCloseWritesNothing() async {
        let store = makeStore(steps: learnAndChoice)
        await store.start(.daily)
        store.close()
        XCTAssertEqual(store.stage, .idle)
        XCTAssertTrue(api.commitBodies.isEmpty)
    }
}
