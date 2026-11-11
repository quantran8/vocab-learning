import Foundation

/// Match Madness game state. Pure value: no clock, network or animation. Elapsed time comes in with each action.
struct MatchMadnessState: Equatable {
    enum Phase: Equatable {
        case playing
        /// `goalMatches` correct pairs: the store stops the clock and commits.
        case goalReached
    }

    /// Pair IDs on the board, in the order they came on.
    var activePairIDs: [String]
    /// Pair IDs still queued, in queue order. A pair that can't come on yet keeps its place.
    var pendingPairIDs: [String]
    /// Per meaning (`word`), the `correctCount` right after it was last matched.
    var matchedAt: [String: Int] = [:]
    /// Word tile IDs, top to bottom.
    var wordOrder: [String] = []
    /// Meaning tile IDs, top to bottom; ordered independently of `wordOrder`.
    var meaningOrder: [String] = []
    var selectedWordTileID: String?
    var selectedMeaningTileID: String?
    var correctCount = 0
    var wrongCount = 0
    var combo = 0
    var longestCombo = 0
    /// Display only (show `max(0, …)`); nil when the plan has no score rule. The server's score is the one that counts.
    var provisionalScore: Int?
    /// Every complete attempt, in order: the commit body.
    var events: [MatchAttemptEvent] = []
    var phase = Phase.playing
}

enum MatchMadnessAction: Equatable {
    case tapWord(tileID: String, elapsedMs: Int)
    case tapMeaning(tileID: String, elapsedMs: Int)
}

/// What the view should play for an action. Presentation only.
enum MatchMadnessFeedback: Equatable {
    case none
    case selected
    case deselected
    case correct(pairID: String, combo: Int)
    case wrong(wordTileID: String, meaningTileID: String)
    case goalReached
}

/// Runs one frozen plan with exactly the server's replay rules (`Board` in vocab-backend
/// `src/modules/challenge/domain/match-madness.ts`, §12.3 of `FRONTEND_FLOW.md`); any drift there is a 422 on commit.
/// The same engine plays a live run, a sandbox plan and the tests.
struct MatchMadnessEngine {
    let plan: ChallengeRunPlan
    private let pairsByID: [String: ChallengePairOccurrence]
    private let pairIDByWordTile: [String: String]
    private let pairIDByMeaningTile: [String: String]

    init(plan: ChallengeRunPlan) {
        self.plan = plan
        pairsByID = Dictionary(plan.pairs.map { ($0.pairId, $0) }, uniquingKeysWith: { first, _ in first })
        pairIDByWordTile = Dictionary(plan.pairs.map { ($0.wordTileId, $0.pairId) }, uniquingKeysWith: { first, _ in first })
        pairIDByMeaningTile = Dictionary(plan.pairs.map { ($0.meaningTileId, $0.pairId) }, uniquingKeysWith: { first, _ in first })
    }

    var goal: Int { plan.goalMatches }

    func pair(_ id: String) -> ChallengePairOccurrence? { pairsByID[id] }
    func wordPair(tileID: String) -> ChallengePairOccurrence? { pairIDByWordTile[tileID].flatMap { pairsByID[$0] } }
    func meaningPair(tileID: String) -> ChallengePairOccurrence? { pairIDByMeaningTile[tileID].flatMap { pairsByID[$0] } }

    func initialState() -> MatchMadnessState {
        var state = MatchMadnessState(
            activePairIDs: [],
            pendingPairIDs: plan.pairs.map(\.pairId),
            provisionalScore: plan.score == nil ? nil : 0
        )
        fill(&state)
        reorder(&state)
        return state
    }

    func reduce(_ state: MatchMadnessState, _ action: MatchMadnessAction) -> (state: MatchMadnessState, feedback: MatchMadnessFeedback) {
        guard state.phase == .playing else { return (state, .none) }
        var next = state
        let elapsedMs: Int
        switch action {
        case .tapWord(let tileID, let elapsed):
            guard next.wordOrder.contains(tileID) else { return (state, .none) }
            if next.selectedWordTileID == tileID {
                next.selectedWordTileID = nil
                return (next, .deselected)
            }
            next.selectedWordTileID = tileID
            elapsedMs = elapsed
        case .tapMeaning(let tileID, let elapsed):
            guard next.meaningOrder.contains(tileID) else { return (state, .none) }
            if next.selectedMeaningTileID == tileID {
                next.selectedMeaningTileID = nil
                return (next, .deselected)
            }
            next.selectedMeaningTileID = tileID
            elapsedMs = elapsed
        }

        guard let wordTileID = next.selectedWordTileID, let meaningTileID = next.selectedMeaningTileID else {
            return (next, .selected)
        }
        return attempt(next, wordTileID: wordTileID, meaningTileID: meaningTileID, elapsedMs: elapsedMs)
    }

    /// The `elapsedMs` the next event would carry: the server wants them strictly increasing.
    static func nextEventElapsed(_ state: MatchMadnessState, reading elapsedMs: Int) -> Int {
        guard let last = state.events.last?.elapsedMs else { return max(elapsedMs, 0) }
        return max(elapsedMs, last + 1)
    }

    private func attempt(
        _ state: MatchMadnessState,
        wordTileID: String,
        meaningTileID: String,
        elapsedMs: Int
    ) -> (state: MatchMadnessState, feedback: MatchMadnessFeedback) {
        var next = state
        next.selectedWordTileID = nil
        next.selectedMeaningTileID = nil
        next.events.append(MatchAttemptEvent(
            seq: next.events.count + 1,
            elapsedMs: Self.nextEventElapsed(state, reading: elapsedMs),
            wordTileId: wordTileID,
            meaningTileId: meaningTileID
        ))

        // Matched by occurrence (same `pairId`), never by text.
        guard let pairID = pairIDByWordTile[wordTileID], pairIDByMeaningTile[meaningTileID] == pairID,
              let pair = pairsByID[pairID] else {
            next.wrongCount += 1
            next.combo = 0
            if let score = plan.score, let current = next.provisionalScore {
                // Like the server, the running total may dip below 0; only the shown value is clamped.
                next.provisionalScore = current - score.mistake
            }
            return (next, .wrong(wordTileID: wordTileID, meaningTileID: meaningTileID))
        }

        next.correctCount += 1
        next.combo += 1
        next.longestCombo = max(next.longestCombo, next.combo)
        if let score = plan.score {
            next.provisionalScore = (next.provisionalScore ?? 0) + score.points(forCombo: next.combo)
        }
        next.activePairIDs.removeAll { $0 == pairID }
        next.matchedAt[pair.word] = next.correctCount
        fill(&next)
        reorder(&next)

        if next.correctCount >= goal {
            if let score = plan.score, let current = next.provisionalScore {
                let clearedAt = next.events.last?.elapsedMs ?? 0
                next.provisionalScore = current + score.clearBonus(timeLimitMs: plan.timeLimitMs, elapsedMs: clearedAt)
            }
            next.phase = .goalReached
            return (next, .goalReached)
        }
        return (next, .correct(pairID: pairID, combo: next.combo))
    }

    /// Tops the board up to `visiblePairs` with the first queued pair whose meaning is neither on the board nor
    /// matched in the last `minMatchesBetweenRepeats` correct matches. If none qualifies and the board is empty, the
    /// head of the queue comes on anyway.
    private func fill(_ state: inout MatchMadnessState) {
        while state.activePairIDs.count < plan.visiblePairs, !state.pendingPairIDs.isEmpty {
            var index = state.pendingPairIDs.firstIndex { canShow($0, in: state) }
            if index == nil, state.activePairIDs.isEmpty { index = 0 }
            guard let index else { return }
            state.activePairIDs.append(state.pendingPairIDs.remove(at: index))
        }
    }

    /// "Same meaning" is the same `word`: a chapter never holds two meanings with one word.
    private func canShow(_ pairID: String, in state: MatchMadnessState) -> Bool {
        guard let pair = pairsByID[pairID] else { return false }
        if state.activePairIDs.contains(where: { pairsByID[$0]?.word == pair.word }) { return false }
        guard let last = state.matchedAt[pair.word] else { return true }
        return state.correctCount - last >= plan.minMatchesBetweenRepeats
    }

    private func reorder(_ state: inout MatchMadnessState) {
        let active = state.activePairIDs.compactMap { pairsByID[$0] }
        state.wordOrder = ChallengeBoardOrdering.order(
            active.map(\.wordTileId), seed: plan.boardSeed, correctCount: state.correctCount, side: .word
        )
        state.meaningOrder = ChallengeBoardOrdering.order(
            active.map(\.meaningTileId), seed: plan.boardSeed, correctCount: state.correctCount, side: .meaning
        )
    }

    /// The commit body for a run that ends now. `goal_reached` ends exactly at the last event.
    static func commitBody(_ state: MatchMadnessState, reason: ChallengeEndedReason, endedElapsedMs: Int) -> ChallengeCommitBody {
        let lastEvent = state.events.last?.elapsedMs ?? 0
        let ended = reason == .goalReached ? lastEvent : max(endedElapsedMs, lastEvent)
        return ChallengeCommitBody(events: state.events, endedReason: reason, endedElapsedMs: ended)
    }
}

// MARK: - Static plans

extension ChallengeRunPlan {
    /// A local plan for previews, tests and the Practice Lab. Never committed. Values mirror the trial policy for
    /// level 2 so the round feels the same; they decide nothing.
    static func sandbox(timeLimitMs: Int = 90_000, visiblePairs: Int = 4, goalMatches: Int = 12) -> ChallengeRunPlan {
        let words: [(String, String)] = [
            ("reimburse", "hoàn trả chi phí"),
            ("allocate", "phân bổ"),
            ("postpone", "trì hoãn"),
            ("clarify", "làm rõ"),
            ("negotiate", "đàm phán"),
            ("deadline", "hạn chót"),
            ("estimate", "ước tính"),
            ("approve", "phê duyệt"),
            ("schedule", "lên lịch"),
            ("invoice", "hoá đơn"),
            ("colleague", "đồng nghiệp"),
            ("review", "xem xét lại"),
        ]
        let pairs = (0..<goalMatches).map { index in
            let (word, meaning) = words[index % words.count]
            return ChallengePairOccurrence(
                pairId: "p\(index + 1)",
                wordTileId: "w\(index + 1)",
                meaningTileId: "m\(index + 1)",
                word: word,
                meaning: meaning
            )
        }
        return ChallengeRunPlan(
            runId: "sandbox",
            gameMode: ChallengeRunPlan.matchMadness,
            chapterNo: 1,
            levelNo: 1,
            policyVersion: "sandbox",
            explanationLocale: "vi-VN",
            goalMatches: goalMatches,
            visiblePairs: visiblePairs,
            timeLimitMs: timeLimitMs,
            minMatchesBetweenRepeats: 3,
            starCriteria: ChallengeStarCriteria(
                two: .init(maxElapsedMs: 80_000, maxMistakes: 3),
                three: .init(maxElapsedMs: 60_000, maxMistakes: 1)
            ),
            boardSeed: "sandbox-seed",
            pairs: pairs,
            score: ChallengeScoreRule(match: 100, streakStep: 10, maxStreakSteps: 5, mistake: 20, perSecondLeft: 5)
        )
    }
}
