import XCTest
@testable import VocabFlow

@MainActor
final class JourneyTests: XCTestCase {
    // MARK: Fixtures

    private func segment(_ number: Int, status: JourneySegment.Status, done: Int, reviewState: JourneyNode.State = .locked) -> JourneySegment {
        let learning = (1...7).map { slot in
            JourneyNode(id: "segment:\(number):learning:\(slot)", segmentNo: number, type: .learning, ordinal: slot,
                        state: slot <= done ? .completed : (status == .active && slot == done + 1 ? .current : .locked),
                        sessionId: nil, reviewId: nil, result: nil)
        }
        let review = JourneyNode(id: "segment:\(number):review", segmentNo: number, type: .review, ordinal: 8,
                                 state: reviewState, sessionId: nil, reviewId: nil, result: nil)
        return JourneySegment(segmentNo: number, status: status, completedLearningCount: done, nodes: learning + [review])
    }

    private func journey(current: Int, segments: [JourneySegment], cursor: Int?) -> Journey {
        Journey(currentSegmentNo: current, focusNodeId: "segment:\(current):learning:1", completedReviewCount: current - 1,
                segments: segments, hasMoreHistory: cursor != nil, nextHistoryCursor: cursor)
    }

    private func makeStore() -> (LearnerStore, StubVocabAPI) {
        let api = StubVocabAPI()
        let plan = LearningPlanStore(storage: InMemoryPreferencesStore(), reminders: NoReminders())
        return (LearnerStore(api: api, plan: plan), api)
    }

    // MARK: Decoding

    func testDecodesBackendJourney() throws {
        let json = #"""
        {"currentSegmentNo":4,"focusNodeId":"segment:4:review","completedReviewCount":3,
         "segments":[{"segmentNo":4,"status":"active","completedLearningCount":7,"nodes":[
           {"id":"segment:4:learning:1","segmentNo":4,"type":"learning","ordinal":1,"state":"completed","sessionId":"ls_401"},
           {"id":"segment:4:review","segmentNo":4,"type":"review","ordinal":8,"state":"current","reviewId":"wr_404"}]},
          {"segmentNo":3,"status":"completed","completedLearningCount":7,"nodes":[
           {"id":"segment:3:review","segmentNo":3,"type":"review","ordinal":8,"state":"completed","reviewId":"wr_303",
            "result":{"reviewedCount":21,"unaidedRecalledCount":15,"needsReviewCount":6}}]}],
         "hasMoreHistory":true,"nextHistoryCursor":3}
        """#
        let journey = try APIClient.decoder.decode(Journey.self, from: Data(json.utf8))
        XCTAssertEqual(journey.currentSegment?.status, .active)
        XCTAssertEqual(journey.focusNode?.reviewId, "wr_404")
        XCTAssertEqual(journey.focusNode?.type, .review)
        XCTAssertEqual(journey.segments[1].nodes[0].result, ReviewResult(reviewedCount: 21, unaidedRecalledCount: 15, needsReviewCount: 6))
        XCTAssertEqual(journey.nextHistoryCursor, 3)
    }

    func testCommitSummaryDecodesReviewResultOnlyWhenSent() throws {
        let plain = try APIClient.decoder.decode(CommitSummary.self, from: Data(#"{"newWordGoalSlots":2,"reviewedMeanings":3,"practiceTasks":9}"#.utf8))
        XCTAssertNil(plain.checkpoint)
        let review = try APIClient.decoder.decode(CommitSummary.self, from: Data(#"""
        {"newWordGoalSlots":0,"reviewedMeanings":0,"practiceTasks":7,"checkpoint":{"reviewedCount":7,"unaidedRecalledCount":4,"needsReviewCount":3}}
        """#.utf8))
        XCTAssertEqual(review.checkpoint?.unaidedRecalledCount, 4)
    }

    // MARK: Layout

    func testSnakeSlotsAlternateRowsOfThree() {
        let slots = (0..<7).map { JourneySnakeLayout.slot($0) }
        XCTAssertEqual(slots.map(\.column), [-1, 0, 1, 1, 0, -1, -1])
        XCTAssertEqual(slots.map(\.level), [0, 0, 0, 1, 1, 1, 2])
        // Below the anchor the rows keep alternating.
        XCTAssertEqual(JourneySnakeLayout.slot(-1).column, -1)
        XCTAssertEqual(JourneySnakeLayout.slot(-1).level, -1)
    }

    func testSnakeRunsOnAcrossSegmentsWithoutGaps() {
        // Five sessions + review: six nodes, so segments don't line up with the two-row pattern.
        let segments = (1...3).map { JourneySegment.placeholder($0, sessions: 5) }
        let layout = JourneySnakeLayout(segments: segments, anchorSegmentNo: 2, width: 353)
        XCTAssertEqual(layout.nodes.count, 18)
        // Every step is to a neighbouring slot: along a row, or straight up the U-turn to the next row.
        for (a, b) in zip(layout.nodes, layout.nodes.dropFirst()) {
            XCTAssertTrue(abs(a.center.y - b.center.y) < 0.001 || abs(a.center.x - b.center.x) < 0.001)
            XCTAssertLessThanOrEqual(a.center.y - b.center.y, JourneySnakeLayout.pitch + 0.001)
            XCTAssertGreaterThanOrEqual(a.center.y - b.center.y, -0.001)
        }
        // The anchor segment starts at slot 0: bottom left of its row.
        let anchorFirst = layout.nodes[6]
        XCTAssertEqual(anchorFirst.id, "segment:2:learning:1")
        XCTAssertLessThan(anchorFirst.center.x, 353 / 2)
        // Everything fits the width and the height.
        XCTAssertTrue(layout.nodes.allSatisfy { $0.center.x - JourneyNodeView.reviewSize / 2 >= -0.001 && $0.center.x + JourneyNodeView.reviewSize / 2 <= 353.001 })
        XCTAssertTrue((layout.nodes.map(\.center) + layout.labels.map(\.center)).allSatisfy { $0.y > 0 && $0.y < layout.size.height })
    }

    func testLoadingOlderHistoryDoesNotMoveNewerNodesAlongTheSnake() {
        let newer = [JourneySegment.placeholder(3, sessions: 5), .placeholder(2, sessions: 5)]
        let before = JourneySnakeLayout(segments: newer, anchorSegmentNo: 2, width: 353)
        let after = JourneySnakeLayout(segments: newer + [.placeholder(1, sessions: 5)], anchorSegmentNo: 2, width: 353)
        for placed in before.nodes {
            XCTAssertEqual(placed.center.x, after.nodes.first { $0.id == placed.id }?.center.x ?? -1, accuracy: 0.001)
        }
    }

    // MARK: Store
    func testRefreshTakesTheServerJourney() async {
        let (store, api) = makeStore()
        let first = journey(current: 1, segments: [segment(2, status: .preview, done: 0), segment(1, status: .active, done: 0)], cursor: nil)
        api.journeyPages[nil] = .success(first)
        await store.refreshJourney()
        XCTAssertEqual(store.journey, first)
        XCTAssertNil(store.journeyError)
    }

    func testFailedRefreshKeepsWhatIsOnScreen() async {
        let (store, api) = makeStore()
        let first = journey(current: 1, segments: [segment(1, status: .active, done: 3)], cursor: nil)
        api.journeyPages[nil] = .success(first)
        await store.refreshJourney()
        api.journeyPages[nil] = .failure(.transport)
        await store.refreshJourney()
        XCTAssertEqual(store.journey, first)
        XCTAssertNotNil(store.journeyError)
    }

    func testLoadOlderAppendsHistoryOnceAndRefreshKeepsIt() async {
        let (store, api) = makeStore()
        api.journeyPages[nil] = .success(journey(
            current: 5,
            segments: [segment(6, status: .preview, done: 0), segment(5, status: .active, done: 2), segment(4, status: .completed, done: 7, reviewState: .completed)],
            cursor: 4
        ))
        api.journeyPages[4] = .success(journey(
            current: 5,
            // Segment 4 again: a page may overlap what is shown.
            segments: [segment(4, status: .completed, done: 7, reviewState: .completed), segment(3, status: .completed, done: 7, reviewState: .completed)],
            cursor: 3
        ))
        await store.refreshJourney()
        await store.loadOlderJourney()
        XCTAssertEqual(store.journey?.segments.map(\.segmentNo), [6, 5, 4, 3])
        XCTAssertEqual(store.journey?.nextHistoryCursor, 3)
        XCTAssertEqual(api.journeyRequests, [nil, 4])

        // After a session the first page changes; the history already loaded below it stays.
        api.journeyPages[nil] = .success(journey(
            current: 5,
            segments: [segment(6, status: .preview, done: 0), segment(5, status: .active, done: 3), segment(4, status: .completed, done: 7, reviewState: .completed)],
            cursor: 4
        ))
        await store.refreshJourney()
        XCTAssertEqual(store.journey?.segments.map(\.segmentNo), [6, 5, 4, 3])
        XCTAssertEqual(store.journey?.currentSegment?.completedLearningCount, 3)
        XCTAssertEqual(store.journey?.nextHistoryCursor, 3)
    }

    func testLoadOlderDoesNothingWithoutMoreHistory() async {
        let (store, api) = makeStore()
        api.journeyPages[nil] = .success(journey(current: 1, segments: [segment(1, status: .active, done: 0)], cursor: nil))
        await store.refreshJourney()
        await store.loadOlderJourney()
        XCTAssertEqual(api.journeyRequests, [nil])
    }

    // MARK: Weekly goal sync

    private func loadStore(localDays: Set<Int>?, serverGoal: Int) async -> StubVocabAPI {
        let api = StubVocabAPI()
        api.storedProfile = UserProfile(
            id: "u1", proficiencyLevel: nil, learningLevel: nil,
            settings: UserSettings(explanationLocale: "vi-VN", uiLocale: AppLanguage.active.uiLocale,
                                   timeZone: TimeZone.current.identifier, dailyNewWordGoal: 5, weeklySessionGoal: serverGoal),
            scope: nil
        )
        var stored = LearningPreferences.default
        if let localDays { stored.learningDays = localDays }
        let storage = InMemoryPreferencesStore(preferences: localDays == nil ? nil : stored)
        let store = LearnerStore(api: api, plan: LearningPlanStore(storage: storage, reminders: NoReminders()))
        await store.load()
        return api
    }

    func testLoadSendsTheDevicesLearningDayCountWhenTheServerDiffers() async {
        let api = await loadStore(localDays: [2, 4, 6], serverGoal: 7)
        XCTAssertEqual(api.settingsUpdates.last?.weeklySessionGoal, 3)
    }

    func testLoadSendsNothingWhenTheGoalAlreadyMatches() async {
        let api = await loadStore(localDays: [2, 4, 6], serverGoal: 3)
        XCTAssertTrue(api.settingsUpdates.isEmpty)
    }

    func testADeviceWithoutASavedPlanNeverOverwritesTheServerGoal() async {
        let api = await loadStore(localDays: nil, serverGoal: 4)
        XCTAssertNil(api.settingsUpdates.last?.weeklySessionGoal)
    }

    func testResetClearsTheJourney() async {
        let (store, api) = makeStore()
        api.journeyPages[nil] = .success(journey(current: 1, segments: [segment(1, status: .active, done: 0)], cursor: nil))
        await store.refreshJourney()
        store.reset()
        XCTAssertNil(store.journey)
    }
}
