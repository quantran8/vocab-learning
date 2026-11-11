import Foundation
import Observation

/// What the results screen shows after the server committed a run.
struct ChallengeRunOutcome: Equatable {
    /// The next chapter is short of words.
    struct WordsNeeded: Equatable {
        let chapterNo: Int
        let eligible: Int
        let required: Int

        var remaining: Int { max(required - eligible, 0) }
    }

    let node: ChallengeNodeRef
    let response: ChallengeCommitResponse
    /// The best before this run, from the map the run was started from (0 for a first play).
    let previousBestStars: Int
    let previousBestScore: Int

    var result: ChallengeRunResult { response.result }
    var isCleared: Bool { result.outcome == .cleared }
    private var unlockKind: ChallengeUnlock.Kind { response.unlock?.kind ?? .none }
    /// The server only reports an unlock on a level's first clear.
    var isFirstClear: Bool {
        isCleared && (previousBestStars == 0 || [.level, .chapterReady, .needsVocabulary].contains(unlockKind))
    }
    /// More stars, or a higher score than before. Display only; both numbers come from the server.
    var isNewBest: Bool {
        guard isCleared, !isFirstClear else { return false }
        return result.bestStars > previousBestStars || result.bestScore > previousBestScore
    }
    var chapterCleared: Bool { unlockKind == .chapterReady || unlockKind == .needsVocabulary }

    /// The level to offer next, as the server decided it.
    var nextNode: ChallengeNodeRef? {
        guard let unlock = response.unlock, let chapterNo = unlock.chapterNo else { return nil }
        switch unlock.kind {
        case .level: return unlock.levelNo.map { ChallengeNodeRef(chapterNo: chapterNo, levelNo: $0) }
        case .chapterReady: return ChallengeNodeRef(chapterNo: chapterNo, levelNo: 1)
        case .needsVocabulary, .none, .unknown: return nil
        }
    }

    var wordsNeeded: WordsNeeded? {
        guard let unlock = response.unlock, unlock.kind == .needsVocabulary, let chapterNo = unlock.chapterNo else { return nil }
        return WordsNeeded(chapterNo: chapterNo, eligible: unlock.eligibleNewCount ?? 0, required: unlock.requiredNewCount ?? 0)
    }
}

/// A Practice Lab round: counted on the device, never sent, never scored.
struct ChallengeSandboxSummary: Equatable {
    let correctMatches: Int
    let goal: Int
    let mistakes: Int
    let longestCombo: Int
    let elapsedMs: Int
    let isTimed: Bool
    let reachedGoal: Bool
}

/// Runs one Match Madness run: issue → ready → start → playing → commit → results.
/// UI orchestration only: the rules live in `MatchMadnessEngine`. Nothing here touches Daily, SRS or learning sessions.
@Observable
@MainActor
final class ChallengeRunStore {
    enum Failure: Equatable {
        case issue(String)
        case start(String)
        case notEnoughVocabulary
        case contentUnavailable(String)
        case expired
        /// The server rejected the events. A contract bug: never shown as a win.
        case invalidEvents(String)
        /// The level or chapter isn't open (any more): back to the map.
        case levelLocked
    }

    enum Stage: Equatable {
        case idle
        case issuing
        /// Plan frozen, clock stopped.
        case ready
        case starting
        case playing
        case committing
        case results(ChallengeRunOutcome)
        case sandboxResults(ChallengeSandboxSummary)
        /// The final body is frozen; retrying sends the same bytes.
        case commitFailed(String)
        /// Another started run is open (maybe on another device). Leaving it ends it with 0 stars.
        case runActive(runID: String?)
        case failed(Failure)
    }

    /// Persisted while a run is open, so a killed app can settle it on the next launch.
    struct PendingRun: Codable, Equatable {
        let runID: String
        let node: ChallengeNodeRef
        var started = false
        /// The frozen commit body, once the run ended.
        var body: Data?
    }

    private(set) var stage: Stage = .idle
    private(set) var plan: ChallengeRunPlan?
    private(set) var game: MatchMadnessState?
    /// Updated about 10 times a second while playing.
    private(set) var elapsedMs = 0
    private(set) var isSandbox = false
    /// False only for the untimed Practice Lab variant (accessibility / familiarization).
    private(set) var isTimed = true
    /// New for every run, so no view state leaks from one attempt into the next.
    private(set) var runToken = UUID()
    /// Tiles flashing as a wrong pair; cleared after `wrongFlashDuration`.
    private(set) var wrongTileIDs: Set<String> = []
    /// Per tile, bumped on every wrong attempt it was part of: drives `ShakeEffect`.
    private(set) var shakeCounts: [String: Int] = [:]
    /// The last action's feedback, with a counter so a repeat still changes.
    private(set) var feedback: (value: MatchMadnessFeedback, count: Int) = (.none, 0)
    /// A short message when `begin()` failed and the run can still be started.
    private(set) var startError: String?

    /// Runs after a run settles on the server (committed, quit or expired): refresh the map.
    var onSettled: (() async -> Void)?

    static let wrongFlashDuration: Duration = .milliseconds(180)
    private static let pendingKey = "challenge.pendingRun"
    private static let tutorialKey = "challenge.tutorialSeen"

    private let api: VocabAPI
    private let haptics: FeedbackProviding
    private let now: () -> ContinuousClock.Instant
    private let tickInterval: Duration?
    private let defaults: UserDefaults?
    private var engine: MatchMadnessEngine?
    private var startedAt: ContinuousClock.Instant?
    private var ticker: Task<Void, Never>?
    private var issuedNode: ChallengeNodeRef?
    private var issuedLevel: ChallengeLevel?
    private var pending: PendingRun?
    /// Set when the run being settled was quit: it closes instead of showing results.
    private var endedReason: ChallengeEndedReason?
    /// One automatic retry each per run: re-issuing over a stale issued run, re-starting before a commit.
    private var retriedIssue = false
    private var retriedStart = false
    /// The commit in flight after a run ended. Tests await it.
    private(set) var settleTask: Task<Void, Never>?

    /// `now` must be monotonic; `tickInterval` nil turns the display timer off (tests call `tick()`).
    init(
        api: VocabAPI,
        haptics: FeedbackProviding,
        now: @escaping () -> ContinuousClock.Instant = { ContinuousClock.now },
        tickInterval: Duration? = .milliseconds(100),
        defaults: UserDefaults? = .standard
    ) {
        self.api = api
        self.haptics = haptics
        self.now = now
        self.tickInterval = tickInterval
        self.defaults = defaults
        pending = defaults?.data(forKey: Self.pendingKey).flatMap { try? JSONDecoder().decode(PendingRun.self, from: $0) }
    }

    var isActive: Bool { stage != .idle }
    var engineGoal: Int { engine?.goal ?? plan?.goalMatches ?? 0 }
    var remainingMs: Int { max((plan?.timeLimitMs ?? 0) - elapsedMs, 0) }
    var hasSeenTutorial: Bool { defaults?.bool(forKey: Self.tutorialKey) ?? true }
    var hasPendingRun: Bool { pending != nil }

    func pair(forWordTile id: String) -> ChallengePairOccurrence? { engine?.wordPair(tileID: id) }
    func pair(forMeaningTile id: String) -> ChallengePairOccurrence? { engine?.meaningPair(tileID: id) }

    // MARK: - Issue and start

    /// Issues a run for `node`. `level` is the map's copy, for the "new best" comparison and the title.
    func play(_ node: ChallengeNodeRef, level: ChallengeLevel?) async {
        guard canIssue else { return }
        resetRunState()
        isSandbox = false
        isTimed = true
        issuedNode = node
        issuedLevel = level
        stage = .issuing
        let token = runToken
        // A run left open by a killed app (or an offline quit) would block this one.
        if pending != nil { await settlePendingRun() }
        guard runToken == token, stage == .issuing else { return }
        do {
            let plan = try await api.issueChallengeRun(chapterNo: node.chapterNo, levelNo: node.levelNo)
            guard runToken == token, stage == .issuing else {
                // Closed while issuing: don't leave an orphan behind.
                try? await api.quitChallengeRun(runID: plan.runId)
                return
            }
            load(plan)
            savePending(PendingRun(runID: plan.runId, node: node))
            stage = .ready
        } catch {
            guard runToken == token, stage == .issuing else { return }
            await handleIssueError(error.asAPIError)
        }
    }

    /// Plays a local plan with the same engine: no API, no commit, no stars.
    func startSandbox(plan: ChallengeRunPlan, timed: Bool) {
        resetRunState()
        isSandbox = true
        isTimed = timed
        load(plan)
        stage = .ready
    }

    /// The clock starts only after the server acknowledged the start.
    func begin() async {
        guard stage == .ready, let plan else { return }
        startError = nil
        markTutorialSeen()
        if !isSandbox {
            stage = .starting
            let token = runToken
            do {
                try await api.startChallengeRun(runID: plan.runId)
            } catch {
                guard runToken == token, stage == .starting else { return }
                let apiError = error.asAPIError
                if apiError.code == ChallengeErrorCode.runExpired {
                    clearPending()
                    stage = .failed(.expired)
                    await onSettled?()
                } else {
                    startError = apiError.userMessage
                    stage = .ready
                }
                return
            }
            guard runToken == token, stage == .starting else { return }
            pending?.started = true
            savePending(pending)
        }
        startedAt = now()
        elapsedMs = 0
        stage = .playing
        startTicker()
    }

    // MARK: - Playing

    func tapWord(_ tileID: String) {
        apply { .tapWord(tileID: tileID, elapsedMs: $0) }
    }

    func tapMeaning(_ tileID: String) {
        apply { .tapMeaning(tileID: tileID, elapsedMs: $0) }
    }

    /// Re-reads the clock. Runs on the display timer and when the app returns to the foreground:
    /// the run never pauses, so a run whose time ran out in the background ends as `time_up`.
    func tick() {
        guard stage == .playing else { return }
        elapsedMs = currentElapsedMs()
        if isTimed, let plan, elapsedMs >= plan.timeLimitMs {
            end(.timeUp, endedElapsedMs: plan.timeLimitMs)
        }
    }

    /// "Exit challenge?" confirmed while playing: commits the run as `quit` (no win) and closes.
    func quit() async {
        switch stage {
        case .playing:
            let elapsed = currentElapsedMs()
            if isTimed, let plan, elapsed >= plan.timeLimitMs {
                // The server counts a quit at the deadline as time up.
                end(.timeUp, endedElapsedMs: plan.timeLimitMs)
            } else {
                end(.quit, endedElapsedMs: elapsed)
            }
            await settleTask?.value
        case .ready, .starting, .issuing:
            await leave()
        default:
            close()
        }
    }

    private func apply(_ action: (Int) -> MatchMadnessAction) {
        guard stage == .playing, let engine, let game, let plan else { return }
        let elapsed = currentElapsedMs()
        if isTimed, elapsed >= plan.timeLimitMs {
            tick()
            return
        }
        elapsedMs = elapsed
        let (next, result) = engine.reduce(game, action(elapsed))
        self.game = next
        feedback = (result, feedback.count + 1)
        switch result {
        case .none:
            break
        case .selected, .deselected:
            haptics.selectionChanged()
        case .correct:
            haptics.success()
        case .wrong(let word, let meaning):
            haptics.error()
            flashWrong([word, meaning])
        case .goalReached:
            haptics.success()
            end(.goalReached, endedElapsedMs: elapsed)
        }
    }

    private func flashWrong(_ tiles: Set<String>) {
        wrongTileIDs.formUnion(tiles)
        for tile in tiles { shakeCounts[tile, default: 0] += 1 }
        let token = runToken
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: Self.wrongFlashDuration)
            guard let self, self.runToken == token else { return }
            self.wrongTileIDs.subtract(tiles)
        }
    }

    // MARK: - Ending and commit

    /// Stops the clock and freezes the commit body. The commit itself runs in `settleTask`.
    private func end(_ reason: ChallengeEndedReason, endedElapsedMs: Int) {
        guard stage == .playing, let game else { return }
        stopTicker()
        endedReason = reason
        elapsedMs = endedElapsedMs

        if isSandbox {
            if reason == .quit {
                close()
                return
            }
            stage = .sandboxResults(ChallengeSandboxSummary(
                correctMatches: game.correctCount,
                goal: engineGoal,
                mistakes: game.wrongCount,
                longestCombo: game.longestCombo,
                elapsedMs: endedElapsedMs,
                isTimed: isTimed,
                reachedGoal: reason == .goalReached
            ))
            return
        }

        let body = MatchMadnessEngine.commitBody(game, reason: reason, endedElapsedMs: endedElapsedMs)
        guard let data = try? body.encoded() else {
            stage = .failed(.invalidEvents(String(localized: "Something went wrong. Please try again.", bundle: .appLanguage)))
            return
        }
        pending?.body = data
        savePending(pending)
        stage = .committing
        settleTask = Task { @MainActor [weak self] in await self?.commit() }
    }

    /// Sends the frozen body again, byte for byte.
    func retryCommit() async {
        guard case .commitFailed = stage else { return }
        stage = .committing
        let task: Task<Void, Never> = Task { @MainActor [weak self] in await self?.commit() }
        settleTask = task
        await task.value
    }

    private func commit() async {
        guard let pending, let body = pending.body else { return }
        do {
            let response = try await api.commitChallengeRun(runID: pending.runID, body: body)
            await settle(with: response)
        } catch {
            let apiError = error.asAPIError
            switch apiError.code {
            case ChallengeErrorCode.commitConflict:
                await recoverFromStatus()
            case ChallengeErrorCode.runNotStarted where !retriedStart:
                // The start answer was lost: start again (idempotent), then send the same body once more.
                retriedStart = true
                if (try? await api.startChallengeRun(runID: pending.runID)) != nil {
                    await commit()
                } else {
                    stage = .commitFailed(apiError.userMessage)
                }
            case ChallengeErrorCode.runNotFound:
                clearPending()
                if endedReason == .quit { close() } else { stage = .failed(.expired) }
                await onSettled?()
            case ChallengeErrorCode.runExpired:
                clearPending()
                if endedReason == .quit { close() } else { stage = .failed(.expired) }
                await onSettled?()
            case ChallengeErrorCode.invalidEvents:
                clearPending()
                stage = .failed(.invalidEvents(apiError.userMessage))
                await onSettled?()
            default:
                if endedReason == .quit {
                    // Kept on disk: the next launch settles it. Quitting never waits on the network.
                    close()
                } else {
                    stage = .commitFailed(apiError.userMessage)
                }
            }
        }
    }

    /// After a conflict or an ambiguous failure: the server's stored answer wins.
    private func recoverFromStatus() async {
        guard let pending else { return }
        do {
            let status = try await api.challengeRunStatus(runID: pending.runID)
            switch status.status {
            case .committed:
                if let response = status.response {
                    await settle(with: response)
                } else {
                    clearPending()
                    close()
                    await onSettled?()
                }
            case .expired, .abandoned:
                clearPending()
                if endedReason == .quit { close() } else { stage = .failed(.expired) }
                await onSettled?()
            case .issued, .started, .unknown:
                stage = .commitFailed(String(localized: "Your result isn’t saved yet.", bundle: .appLanguage))
            }
        } catch {
            stage = .commitFailed(error.asAPIError.userMessage)
        }
    }

    private func settle(with response: ChallengeCommitResponse) async {
        let node = pending?.node ?? issuedNode ?? ChallengeNodeRef(chapterNo: plan?.chapterNo ?? 1, levelNo: plan?.levelNo ?? 1)
        clearPending()
        if endedReason == .quit {
            close()
        } else {
            stage = .results(ChallengeRunOutcome(
                node: node,
                response: response,
                previousBestStars: issuedLevel?.bestStars ?? 0,
                previousBestScore: issuedLevel?.bestScore ?? 0
            ))
        }
        await onSettled?()
    }

    // MARK: - Leaving

    /// Leaves before the clock started: the issued run is cancelled on the server.
    func leave() async {
        let runID = pending?.started == false ? pending?.runID : nil
        if !isSandbox, let runID {
            clearPending()
            close()
            try? await api.quitChallengeRun(runID: runID)
            await onSettled?()
        } else {
            close()
        }
    }

    /// From `.runActive`: ends the other run, then issues the one that was asked for.
    func leaveActiveRunAndRetry() async {
        guard case .runActive(let runID) = stage, let node = issuedNode else { return }
        let level = issuedLevel
        if let runID {
            try? await api.quitChallengeRun(runID: runID)
            clearPending()
        }
        stage = .idle
        await play(node, level: level)
    }

    /// Back to where the run was started from.
    func close() {
        stopTicker()
        resetRunState()
        isSandbox = false
        isTimed = true
        stage = .idle
    }

    /// Sign-out: forget the run, including what's on disk (the server's TTL settles it).
    func reset() {
        close()
        clearPending()
    }

    // MARK: - Recovery

    /// Settles a run the app was killed in. Silent: the map refreshes afterwards. Never grants anything locally.
    func recoverPendingRun() async {
        guard stage == .idle else { return }
        await settlePendingRun()
    }

    private func settlePendingRun() async {
        guard let pending else { return }
        do {
            let status = try await api.challengeRunStatus(runID: pending.runID)
            switch status.status {
            case .committed, .expired, .abandoned:
                clearPending()
            case .issued:
                try? await api.quitChallengeRun(runID: pending.runID)
                clearPending()
            case .started:
                if let body = pending.body, (try? await api.commitChallengeRun(runID: pending.runID, body: body)) != nil {
                    clearPending()
                } else {
                    // The events weren't saved, so the run can't be resumed reliably: settle it with 0 stars.
                    try? await api.quitChallengeRun(runID: pending.runID)
                    clearPending()
                }
            case .unknown:
                return
            }
            await onSettled?()
        } catch {
            if error.asAPIError.status == 404 { clearPending() }
        }
    }

    // MARK: - Helpers

    private var canIssue: Bool {
        switch stage {
        case .idle, .results, .sandboxResults, .failed, .runActive: true
        default: false
        }
    }

    private func handleIssueError(_ error: APIError) async {
        switch error.code {
        case ChallengeErrorCode.runActive:
            await handleRunActive(runID: error.detail("runId") ?? pending?.runID)
        case ChallengeErrorCode.levelLocked:
            stage = .failed(.levelLocked)
            await onSettled?()
        case ChallengeErrorCode.notEnoughVocabulary:
            stage = .failed(.notEnoughVocabulary)
            await onSettled?()
        case ChallengeErrorCode.contentUnavailable:
            stage = .failed(.contentUnavailable(error.userMessage))
        default:
            stage = .failed(.issue(error.userMessage))
        }
    }

    /// An issued run holds nothing played, so it is dropped and this level issued again. A started one may be
    /// in play elsewhere: the learner decides.
    private func handleRunActive(runID: String?) async {
        guard let runID else {
            stage = .runActive(runID: nil)
            return
        }
        let status = try? await api.challengeRunStatus(runID: runID)
        guard stage == .issuing else { return }
        if status?.status == .issued, !retriedIssue, let node = issuedNode {
            retriedIssue = true
            try? await api.quitChallengeRun(runID: runID)
            if pending?.runID == runID { clearPending() }
            do {
                let plan = try await api.issueChallengeRun(chapterNo: node.chapterNo, levelNo: node.levelNo)
                guard stage == .issuing else { return }
                load(plan)
                savePending(PendingRun(runID: plan.runId, node: node))
                stage = .ready
            } catch {
                guard stage == .issuing else { return }
                await handleIssueError(error.asAPIError)
            }
            return
        }
        stage = .runActive(runID: runID)
    }

    private func load(_ plan: ChallengeRunPlan) {
        let engine = MatchMadnessEngine(plan: plan)
        self.plan = plan
        self.engine = engine
        game = engine.initialState()
    }

    private func resetRunState() {
        stopTicker()
        plan = nil
        engine = nil
        game = nil
        startedAt = nil
        elapsedMs = 0
        wrongTileIDs = []
        shakeCounts = [:]
        feedback = (.none, 0)
        startError = nil
        endedReason = nil
        issuedLevel = nil
        retriedIssue = false
        retriedStart = false
        runToken = UUID()
    }

    private func currentElapsedMs() -> Int {
        guard let startedAt else { return 0 }
        let components = (now() - startedAt).components
        return max(Int(components.seconds) * 1000 + Int(components.attoseconds / 1_000_000_000_000_000), 0)
    }

    private func startTicker() {
        stopTicker()
        guard let tickInterval else { return }
        ticker = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: tickInterval)
                guard let self, !Task.isCancelled else { return }
                self.tick()
            }
        }
    }

    private func stopTicker() {
        ticker?.cancel()
        ticker = nil
    }

    private func markTutorialSeen() {
        defaults?.set(true, forKey: Self.tutorialKey)
    }

    private func savePending(_ run: PendingRun?) {
        pending = run
        guard let defaults else { return }
        if let run, let data = try? JSONEncoder().encode(run) {
            defaults.set(data, forKey: Self.pendingKey)
        } else {
            defaults.removeObject(forKey: Self.pendingKey)
        }
    }

    private func clearPending() {
        savePending(nil)
    }
}
