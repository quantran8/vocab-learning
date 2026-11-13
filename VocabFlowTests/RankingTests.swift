import XCTest
@testable import VocabFlow

/// LP, lifetime Tier and the weekly ranking: wire decoding, session LP across commits, and the opt-in rules.
@MainActor
final class RankingTests: XCTestCase {
    private let api = StubVocabAPI()
    private let summary = CommitSummary(newWordGoalSlots: 1, reviewedMeanings: 0, practiceTasks: 2)
    private let weekEnd = Date(timeIntervalSince1970: 1_763_251_200)

    private func decode<T: Decodable>(_ type: T.Type, _ json: String) throws -> T {
        try APIClient.decoder.decode(T.self, from: Data(json.utf8))
    }

    private func meta(enabled: Bool) -> RankingMeta {
        RankingMeta(weekStart: "2026-11-09", weekEndsAt: weekEnd, rankingEnabled: enabled, tiers: [],
                    avatarKeys: ["syllie_calm"], reportReasons: ["offensive_name", "other"])
    }

    private func mine(listed: Bool) -> MyRanking {
        MyRanking(weekStart: "2026-11-09", weekEndsAt: weekEnd, weeklyLP: listed ? 30 : 0, listed: listed,
                  position: listed ? RankingPosition(kind: .rank, rank: 2, percentile: nil) : nil,
                  tier: TierDetailSummary(level: 1, key: .firstSteps, lifetimeLP: 45, lifetimeActiveDays: 2, nextTier: nil))
    }

    private func board(_ rows: [LeaderboardRow]) -> Leaderboard {
        Leaderboard(weekStart: "2026-11-09", weekEndsAt: weekEnd, rows: rows)
    }

    // MARK: Decoding

    func testDecodesProfileRankingFieldsAndStaysCompatible() throws {
        let profile = try decode(UserProfile.self, #"""
        {"id":"u1","proficiencyLevel":"B1","learningLevel":null,"scope":null,
         "settings":{"explanationLocale":"vi-VN","uiLocale":"vi-VN","timeZone":"Asia/Ho_Chi_Minh","dailyNewWordGoal":5,"leaderboardVisible":false},
         "username":"brave_otter_0042","avatarKey":"syllie_brave","usernameChangeAvailableAt":null,"rankingIntroSeen":false,
         "tierSummary":{"level":0,"key":null,"lifetimeLP":15,"lifetimeActiveDays":1}}
        """#)
        XCTAssertEqual(profile.username, "brave_otter_0042")
        XCTAssertEqual(profile.settings.leaderboardVisible, false)
        XCTAssertEqual(profile.tierSummary, TierSummary(level: 0, key: nil, lifetimeLP: 15, lifetimeActiveDays: 1))

        let old = try decode(UserProfile.self, #"""
        {"id":"u1","proficiencyLevel":null,"learningLevel":null,"scope":null,
         "settings":{"explanationLocale":"vi-VN","uiLocale":"vi-VN","timeZone":"UTC","dailyNewWordGoal":5}}
        """#)
        XCTAssertNil(old.tierSummary)
        XCTAssertNil(old.settings.leaderboardVisible)
    }

    func testDecodesCommitLPAndAnUnknownTierKey() throws {
        let response = try decode(CommitResponse.self, #"""
        {"sessionId":"s1","status":"committed","committedAt":"2026-11-12T03:00:00.000Z",
         "summary":{"newWordGoalSlots":2,"reviewedMeanings":2,"practiceTasks":6},
         "lp":{"earned":18,"breakdown":{"newMeaningLP":10,"dueReviewLP":8,"extraPracticeLP":0},"lpPolicyVersion":"lp_effort_trial_v1","weeklyLP":330,"lifetimeLP":600},
         "tier":{"level":3,"key":"building_up","lifetimeActiveDays":30,
                 "tierUps":[{"level":2,"key":"in_motion","unlockedAt":"2026-11-12T03:00:00.000Z"},{"level":3,"key":"something_new","unlockedAt":"2026-11-12T03:00:00.000Z"}],
                 "nextTier":{"level":4,"key":"steady_effort","minLifetimeLP":1500,"minLifetimeActiveDays":90}},
         "ranking":{"weeklyLP":330,"listed":false}}
        """#)
        XCTAssertEqual(response.lp?.breakdown, LPBreakdown(newMeaningLP: 10, dueReviewLP: 8, extraPracticeLP: 0))
        XCTAssertEqual(response.tier?.tierUps.map(\.key), [.inMotion, .unknown])
        XCTAssertEqual(response.ranking, CommitRanking(weeklyLP: 330, listed: false))

        let old = try decode(CommitResponse.self, #"{"sessionId":"s1","summary":{"newWordGoalSlots":1,"reviewedMeanings":0,"practiceTasks":1}}"#)
        XCTAssertNil(old.lp)
    }

    // MARK: Session LP

    func testSessionAddsUpReviewAndNewWordCommitsAndCelebratesTheHighestTier() async {
        let unlocked = Date(timeIntervalSince1970: 1_762_916_400)
        let review = CommitResponse(sessionId: "s1", summary: summary,
                                    lp: CommitLP(earned: 4, breakdown: LPBreakdown(dueReviewLP: 4), weeklyLP: 39, lifetimeLP: 39),
                                    tier: CommitTier(level: 0, key: nil, lifetimeActiveDays: 1, tierUps: [], nextTier: nil))
        let learned = CommitResponse(sessionId: "s2", summary: summary,
                                     lp: CommitLP(earned: 5, breakdown: LPBreakdown(newMeaningLP: 5), weeklyLP: 44, lifetimeLP: 44),
                                     tier: CommitTier(level: 1, key: .firstSteps, lifetimeActiveDays: 1,
                                                      tierUps: [TierUp(level: 1, key: .firstSteps, unlockedAt: unlocked)], nextTier: nil))
        api.plan = .success(SessionPlan(sessionID: "s1", mode: .daily, steps: [.practice(phase: .dueReview, task: PracticeFixtures.choice())]))
        api.commitResults = [.success(review), .success(learned)]
        let store = PracticeSessionStore(api: api, audio: SilentAudioClips(), recorder: StubRecorder(), haptics: NoOpFeedback(),
                                         recordingScoring: .backend, transcriber: StubTranscriber())

        await store.start(.daily)
        store.submitOption(3)
        api.plan = .success(SessionPlan(sessionID: "s2", mode: .daily, steps: [
            .learn(id: "l1", card: PracticeFixtures.card),
            .practice(phase: .newPractice, task: PracticeFixtures.choice()),
        ]))
        store.advance()
        await waitForStage(store) { $0 == .reviewFinished }
        store.continueToPractice()
        store.advance()
        store.submitOption(3)
        store.advance()
        await waitForStage(store) { if case .finished = $0 { true } else { false } }

        XCTAssertEqual(store.effort?.earned, 9)
        XCTAssertEqual(store.effort?.breakdown, LPBreakdown(newMeaningLP: 5, dueReviewLP: 4, extraPracticeLP: 0))
        XCTAssertEqual(store.effort?.lifetimeLP, 44)
        XCTAssertEqual(store.effort?.celebratedTierUp?.key, .firstSteps)
    }

    func testOldBackendLeavesNoEffort() {
        var effort = SessionEffort()
        effort.add(lp: CommitLP(earned: 0, weeklyLP: 0, lifetimeLP: 0), tier: nil)
        XCTAssertNil(effort.celebratedTierUp)
        XCTAssertEqual(effort.earned, 0)
    }

    private func waitForStage(_ store: PracticeSessionStore, where matches: (PracticeSessionStore.Stage) -> Bool) async {
        for _ in 0..<2000 where !matches(store.stage) {
            await Task.yield()
        }
    }

    // MARK: Ranking store

    func testUnlistedLearnerLoadsTheTopBoardOnly() async {
        api.rankingMetaResult = .success(meta(enabled: true))
        api.myRankingResult = .success(mine(listed: false))
        api.leaderboards[.top] = .success(board([
            LeaderboardRow(rank: 1, username: "a", avatarKey: "syllie_calm", weeklyLP: 50, lifetimeTier: TierBadge(level: 0, key: nil), isMe: false),
        ]))
        let store = RankingStore(api: api)
        await store.refreshRanking()
        XCTAssertEqual(api.leaderboardRequests, [.top])
        XCTAssertEqual(store.top.count, 1)
        XCTAssertEqual(store.around, [])
        XCTAssertFalse(store.isBoardClosed)
        XCTAssertEqual(store.reportReasons, [.offensiveName, .other])
    }

    func testClosedGateSkipsTheBoardButKeepsTheWeek() async {
        api.rankingMetaResult = .success(meta(enabled: false))
        api.myRankingResult = .success(mine(listed: false))
        let store = RankingStore(api: api)
        await store.refreshRanking()
        XCTAssertTrue(store.isBoardClosed)
        XCTAssertEqual(api.leaderboardRequests, [])
        XCTAssertEqual(store.mine?.tier.level, 1)
        XCTAssertNil(store.error)
    }

    func testSeeingTheIntroNeverOptsIn() async throws {
        let store = RankingStore(api: api)
        var profileReloads = 0
        store.onProfileChanged = { profileReloads += 1 }
        await store.markIntroSeen()
        XCTAssertEqual(api.introSeenCalls, 1)
        XCTAssertEqual(api.settingsUpdates, [])

        api.rankingMetaResult = .success(meta(enabled: true))
        api.myRankingResult = .success(mine(listed: true))
        api.leaderboards[.top] = .success(board([]))
        api.leaderboards[.around] = .success(board([]))
        try await store.setVisible(true)
        XCTAssertEqual(api.settingsUpdates, [SettingsUpdate(leaderboardVisible: true)])
        XCTAssertEqual(api.leaderboardRequests.sorted { $0.rawValue < $1.rawValue }, [.around, .top])
        XCTAssertEqual(profileReloads, 2)
    }

    func testOptInBodyCarriesOnlyTheFlag() throws {
        let body = try PracticeFixtures.json(SettingsUpdate(leaderboardVisible: true)) as? [String: Bool]
        XCTAssertEqual(body, ["leaderboardVisible": true])
    }

    func testUsernameRuleMatchesTheServer() {
        XCTAssertTrue(EditPublicProfileSheet.isWellFormed("alan.lee_7"))
        XCTAssertFalse(EditPublicProfileSheet.isWellFormed("ab"))
        XCTAssertFalse(EditPublicProfileSheet.isWellFormed("1abc"))
        XCTAssertFalse(EditPublicProfileSheet.isWellFormed("a..b"))
        XCTAssertFalse(EditPublicProfileSheet.isWellFormed(String(repeating: "a", count: 21)))
    }

    func testWeekLabelReadsInUTC() {
        XCTAssertNotNil(WeekLabel.range("2026-11-09"))
        XCTAssertNil(WeekLabel.range("not-a-date"))
    }
}
