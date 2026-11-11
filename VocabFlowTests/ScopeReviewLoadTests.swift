import XCTest
@testable import VocabFlow

/// Scope completion, review load and "I know this": wire decoding, the Home card status and the session rules.
@MainActor
final class ScopeReviewLoadTests: XCTestCase {
    private let api = StubVocabAPI()
    private let summary = CommitSummary(newWordGoalSlots: 1, reviewedMeanings: 0, practiceTasks: 2)

    private func makeStore(_ plan: SessionPlan) -> PracticeSessionStore {
        api.plan = .success(plan)
        return PracticeSessionStore(api: api, audio: SilentAudioClips(), recorder: StubRecorder(), haptics: NoOpFeedback(),
                                    recordingScoring: .backend, transcriber: StubTranscriber())
    }

    private func waitForStage(_ store: PracticeSessionStore, where matches: (PracticeSessionStore.Stage) -> Bool) async {
        for _ in 0..<1000 where !matches(store.stage) {
            await Task.yield()
        }
    }

    private func commitBody() throws -> [String: Any] {
        try XCTUnwrap(JSONSerialization.jsonObject(with: XCTUnwrap(api.commitBodies.last)) as? [String: Any])
    }

    // MARK: Decoding

    func testDecodesPlanExtras() throws {
        let json = #"""
        {"sessionId":"s1","mode":"daily","newWords":{"requested":5,"issued":2,"withheldReason":"user_override"},
         "reviewWords":[{"wordId":"w1","meaningId":"m1","lemma":"go","sourceTopic":{"id":"t1","name":"Travel"}}],
         "steps":[
          {"type":"practice","phase":"due_review","sourceTopic":{"id":"t1","name":"Travel"},
           "task":{"id":"r1","template":"typing","variant":"meaning_recall","prompt":{"type":"text","text":"đi"},"evaluation":{"acceptedResponses":["go"]}}},
          {"type":"practice","phase":"known_check",
           "task":{"id":"k1","template":"typing","variant":"meaning_recall","prompt":{"type":"text","text":"làm rõ"},"evaluation":{"acceptedResponses":["clarify"]}}},
          {"type":"learn","id":"l1","knownCheckTaskId":"k1","skippableTaskIds":["n1"],"card":{"word":"clarify","meaning":"làm rõ","definition":null}}
         ]}
        """#
        let plan = try APIClient.decoder.decode(SessionPlan.self, from: Data(json.utf8))
        XCTAssertEqual(plan.newWords, NewWordsIssue(requested: 5, issued: 2, withheldReason: .userOverride))
        XCTAssertEqual(plan.reviewWords?.first?.sourceTopic?.name, "Travel")
        XCTAssertEqual(plan.sourceTopics["r1"]?.name, "Travel")
        XCTAssertEqual(plan.knownChecks["k1"], KnownCheck(learnStepID: "l1", skippableTaskIDs: ["n1"]))
        guard case .practice(.knownCheck, _) = plan.steps[1] else { return XCTFail("Not a known check") }
    }

    func testUnknownReasonDoesNotFailTheHome() throws {
        let json = #"""
        {"dueCount":34,"checkpointAvailable":0,"checkpointSessionsDone":0,"checkpointSessionsRequired":7,"learnedTotal":80,
         "scope":{"status":"exhausted","remainingNewMeanings":0,"pendingCustomMeanings":3,"sessionsLeftEstimate":null,"topics":[]},
         "reviewLoad":{"backlog":34,"dueCap":10,"effectiveNewPerSession":2,"newWordReason":"something_new",
                       "override":{"value":2,"mode":"until_date","until":"2026-11-15T16:59:59.000Z"},"autoBalance":false,"promptChoice":true}}
        """#
        let home = try APIClient.decoder.decode(LearnHome.self, from: Data(json.utf8))
        XCTAssertEqual(home.reviewLoad?.newWordReason, .unknown)
        XCTAssertEqual(home.reviewLoad?.override?.mode, .untilDate)
        XCTAssertEqual(home.scope?.status, .exhausted)
    }

    func testFilterEncodesTheOneKeyTheBackendExpects() throws {
        let encode = { (filter: PracticeFilter) in try PracticeFixtures.json(filter) as? [String: AnyHashable] }
        XCTAssertEqual(try encode(.collection("c1")), ["collectionId": "c1"])
        XCTAssertEqual(try encode(.topic("t1")), ["topicIds": ["t1"]])
        XCTAssertEqual(try encode(.customWords), ["customOnly": true])
    }

    // MARK: Home card

    private func home(scope: ScopeState? = nil, load: ReviewLoad? = nil) -> LearnHome {
        LearnHome(dueCount: load?.backlog ?? 0, checkpointAvailable: 0, checkpointSessionsDone: 0, checkpointSessionsRequired: 7,
                  learnedTotal: 0, scope: scope, reviewLoad: load)
    }

    private func load(backlog: Int = 0, effective: Int = 5, reason: NewWordReason = .goal) -> ReviewLoad {
        ReviewLoad(backlog: backlog, dueCap: 10, effectiveNewPerSession: effective, newWordReason: reason, override: nil, autoBalance: false, promptChoice: false)
    }

    func testHomeStatusFromAnOlderBackendShowsTheGoal() {
        let status = DailyLessonStatus(home: home(), goal: 5)
        XCTAssertEqual(status.newWords, 5)
        XCTAssertEqual(status.scope, .ok)
        XCTAssertNil(status.reason)
    }

    func testExhaustedScopeWithAndWithoutOwnWords() {
        let exhausted = { (custom: Int) in ScopeState(status: .exhausted, remainingNewMeanings: 0, pendingCustomMeanings: custom, sessionsLeftEstimate: nil, topics: []) }
        XCTAssertEqual(DailyLessonStatus(home: home(scope: exhausted(0)), goal: 5).scope, .exhaustedNoCustom)
        XCTAssertEqual(DailyLessonStatus(home: home(scope: exhausted(3)), goal: 5).scope, .exhaustedWithCustom(3))
    }

    func testLowScopeAndAutoBalanceReason() {
        let low = ScopeState(status: .low, remainingNewMeanings: 12, pendingCustomMeanings: 0, sessionsLeftEstimate: 3, topics: [])
        let status = DailyLessonStatus(home: home(scope: low, load: load(backlog: 34, effective: 2, reason: .autoBalanced)), goal: 5)
        XCTAssertEqual(status.scope, .low(remaining: 12, sessions: 3))
        XCTAssertEqual(status.reason, .autoBalanced)
        XCTAssertEqual(status.newWords, 2)
        XCTAssertEqual(status.backlog, 34)
    }

    // MARK: Session

    private let review: [PlanStep] = [.practice(phase: .dueReview, task: PracticeFixtures.choice(id: "r1"))]

    func testWithheldNewWordsEndTheSessionInsteadOfPlanningAgain() async {
        let store = makeStore(SessionPlan(sessionID: "s1", mode: .daily, steps: review,
                                          newWords: NewWordsIssue(requested: 5, issued: 0, withheldReason: .scopeExhausted)))
        api.commitResults = [.success(CommitResponse(sessionId: "s1", summary: summary))]
        await store.start(.daily)
        store.submitOption(3)
        store.advance()
        await waitForStage(store) { $0 != .running && $0 != .committing }

        XCTAssertEqual(store.stage, .finished(summary))
        XCTAssertEqual(api.planRequests.count, 1, "No second daily plan: it would answer the same")
    }

    func testReviewOnlyAsksForNoNewWordsAndNeverContinues() async {
        let store = makeStore(SessionPlan(sessionID: "s1", mode: .daily, steps: review))
        api.commitResults = [.success(CommitResponse(sessionId: "s1", summary: summary))]
        await store.startReviewOnly()
        XCTAssertEqual(api.planRequests.last?.reviewOnly, true)
        XCTAssertNil(api.planRequests.last?.knownCheck)
        store.continueToPractice()
        store.submitOption(3)
        store.advance()
        await waitForStage(store) { $0 != .running && $0 != .committing }
        XCTAssertEqual(store.stage, .finished(summary))
        XCTAssertEqual(api.planRequests.count, 1)
    }

    func testRandomPracticeSendsTheChosenSource() async {
        let store = makeStore(SessionPlan(sessionID: nil, mode: .randomPractice, steps: []))
        await store.startPractice([], filter: .topic("t1"))
        XCTAssertEqual(api.planRequests.last?.filter, .topic("t1"))
        XCTAssertNil(api.planRequests.last?.skills)
        XCTAssertEqual(store.stage, .empty)
    }

    func testScopeEventsComeWithTheResults() async {
        let events = ScopeEvents(completedTopicIds: ["t1"], scopeExhausted: true, collectionCompleted: false)
        let store = makeStore(SessionPlan(sessionID: "s1", mode: .randomPractice, steps: review))
        api.commitResults = [.success(CommitResponse(sessionId: "s1", summary: summary, scopeEvents: events))]
        await store.startPractice([])
        store.continueToPractice()
        store.submitOption(3)
        store.advance()
        await waitForStage(store) { $0 != .running && $0 != .committing }
        XCTAssertEqual(store.scopeEvents, events)
    }

    // MARK: "I know this"

    private var knownCheckPlan: SessionPlan {
        SessionPlan(
            sessionID: "s1", mode: .daily,
            steps: [
                .practice(phase: .knownCheck, task: PracticeFixtures.typing(id: "k1")),
                .learn(id: "l1", card: PracticeFixtures.card),
                .practice(phase: .newPractice, task: PracticeFixtures.choice(id: "n1")),
                .practice(phase: .newPractice, task: PracticeFixtures.match()),
            ],
            knownChecks: ["k1": KnownCheck(learnStepID: "l1", skippableTaskIDs: ["n1"])]
        )
    }

    func testKnownCheckIsRequestedOnlyWhenOffered() async {
        let store = makeStore(knownCheckPlan)
        store.offersKnownCheck = { true }
        await store.start(.daily)
        XCTAssertEqual(api.planRequests.last?.knownCheck, true)
    }

    func testPassedCheckSkipsTheCardAndItsOwnTasks() async throws {
        let store = makeStore(knownCheckPlan)
        api.commitResults = [.success(CommitResponse(sessionId: "s1", summary: summary))]
        await store.start(.daily)
        XCTAssertTrue(store.isKnownCheck)
        store.submitText("clarify")
        store.advance()

        XCTAssertEqual(store.knownWordCount, 1)
        guard case .practice(_, let task)? = store.currentStep else { return XCTFail("Expected the shared match task") }
        XCTAssertEqual(task.id, "t-match")
        store.submitPair(leftID: 1, rightID: 5)
        store.submitPair(leftID: 2, rightID: 6)
        store.advance()
        await waitForStage(store) { $0 != .running && $0 != .committing }

        let body = try commitBody()
        XCTAssertEqual(body["learnStepsCompleted"] as? [String], [])
        let ids = (body["taskResults"] as? [[String: Any]])?.compactMap { $0["taskId"] as? String }
        XCTAssertEqual(ids, ["k1", "t-match"])
    }

    func testDeclinedCheckTeachesTheWordAndSendsNoCheckResult() async throws {
        let store = makeStore(knownCheckPlan)
        api.commitResults = [.success(CommitResponse(sessionId: "s1", summary: summary))]
        await store.start(.daily)
        store.declineKnownCheck()
        guard case .learn("l1", _)? = store.currentStep else { return XCTFail("Expected the Learn card") }
        store.advance()
        store.submitOption(3)
        store.advance()
        store.submitPair(leftID: 1, rightID: 5)
        store.submitPair(leftID: 2, rightID: 6)
        store.advance()
        await waitForStage(store) { $0 != .running && $0 != .committing }

        let body = try commitBody()
        XCTAssertEqual(body["learnStepsCompleted"] as? [String], ["l1"])
        let ids = (body["taskResults"] as? [[String: Any]])?.compactMap { $0["taskId"] as? String }
        XCTAssertEqual(ids, ["n1", "t-match"])
        XCTAssertEqual(store.knownWordCount, 0)
    }

    func testWrongCheckGoesOnToTheCard() async {
        let store = makeStore(knownCheckPlan)
        await store.start(.daily)
        store.submitText("nope")
        store.reveal()
        store.advance()
        guard case .learn("l1", _)? = store.currentStep else { return XCTFail("Expected the Learn card") }
        XCTAssertEqual(store.knownWordCount, 0)
    }
}
