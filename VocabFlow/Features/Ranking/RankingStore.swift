import Foundation
import Observation

/// Lifetime Tier and the weekly leaderboard (FRONTEND_FLOW §14). Everything here is a cache of the server:
/// LP is only ever earned by a session commit, and Tier never goes down.
@Observable
@MainActor
final class RankingStore {
    private(set) var meta: RankingMeta?
    private(set) var mine: MyRanking?
    private(set) var tier: TierDetail?
    private(set) var top: [LeaderboardRow] = []
    private(set) var around: [LeaderboardRow] = []
    /// Set when the last load failed; whatever was on screen stays.
    private(set) var error: String?
    private(set) var isLoading = false
    /// The server's launch gate is closed: Tier and LP still work, the board does not.
    private(set) var isBoardClosed = false

    /// The profile holds the username, avatar, opt-in and the Tier summary, so it reloads after any change here.
    var onProfileChanged: () async -> Void = {}

    private let api: VocabAPI
    /// Bumped by `reset`, so an answer for the previous account is dropped.
    private var generation = 0

    init(api: VocabAPI) {
        self.api = api
    }

    /// Avatar allowlist, report reasons and the launch gate, without loading the board.
    func loadMeta() async {
        guard meta == nil else { return }
        let started = generation
        guard let fetched = try? await api.rankingMeta(), started == generation else { return }
        meta = fetched
        isBoardClosed = !fetched.rankingEnabled
    }

    func refreshTier() async {
        let started = generation
        do {
            let detail = try await api.tierDetail()
            guard started == generation else { return }
            tier = detail
        } catch {
            guard started == generation, !Task.isCancelled else { return }
            self.error = error.asAPIError.userMessage
        }
    }

    /// The board views only load when the gate is open, and "around me" only for a listed learner.
    func refreshRanking() async {
        let started = generation
        isLoading = true
        defer { if started == generation { isLoading = false } }
        do {
            async let meta = api.rankingMeta()
            async let mine = api.myRanking()
            let (fetchedMeta, fetchedMine) = try await (meta, mine)
            guard started == generation else { return }
            self.meta = fetchedMeta
            self.mine = fetchedMine
            isBoardClosed = !fetchedMeta.rankingEnabled
            if fetchedMeta.rankingEnabled {
                try await loadBoard(listed: fetchedMine.listed, started: started)
            } else {
                top = []
                around = []
            }
            error = nil
        } catch {
            guard started == generation, !Task.isCancelled else { return }
            let apiError = error.asAPIError
            if apiError.code == "RANKING_DISABLED" {
                isBoardClosed = true
                top = []
                around = []
            } else {
                self.error = apiError.userMessage
            }
        }
    }

    private func loadBoard(listed: Bool, started: Int) async throws {
        async let top = api.leaderboard(.top)
        async let around = aroundRows(listed: listed)
        let (topBoard, aroundRows) = try await (top, around)
        guard started == generation else { return }
        self.top = topBoard.rows
        self.around = aroundRows
    }

    private func aroundRows(listed: Bool) async throws -> [LeaderboardRow] {
        listed ? try await api.leaderboard(.around).rows : []
    }

    /// Opt-in or opt-out. Only an explicit choice calls this, never dismissing the intro.
    func setVisible(_ visible: Bool) async throws {
        try await api.updateSettings(SettingsUpdate(leaderboardVisible: visible))
        async let profile: Void = onProfileChanged()
        async let ranking: Void = refreshRanking()
        _ = await (profile, ranking)
    }

    /// Records that the intro was shown; it does not opt the learner in.
    func markIntroSeen() async {
        try? await api.markRankingIntroSeen()
        await onProfileChanged()
    }

    func updateProfile(username: String?, avatarKey: String?) async throws -> PublicProfile {
        let saved = try await api.updatePublicProfile(PublicProfileUpdate(username: username, avatarKey: avatarKey))
        await onProfileChanged()
        if mine != nil { await refreshRanking() }
        return saved
    }

    func report(username: String, reason: ReportReason) async throws {
        try await api.reportLearner(username: username, reason: reason)
    }

    /// Reasons the server accepts, in the client's order.
    var reportReasons: [ReportReason] {
        guard let allowed = meta?.reportReasons else { return ReportReason.allCases }
        return ReportReason.allCases.filter { allowed.contains($0.rawValue) }
    }

    var avatarKeys: [String] { meta?.avatarKeys ?? [] }

    func reset() {
        generation += 1
        meta = nil
        mine = nil
        tier = nil
        top = []
        around = []
        error = nil
        isLoading = false
        isBoardClosed = false
    }
}
