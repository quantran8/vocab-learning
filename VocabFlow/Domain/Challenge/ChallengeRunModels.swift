import Foundation

// Wire models for a challenge run (vocab-backend `docs/FRONTEND_FLOW.md` §12.2–12.4):
// issue → start → commit, plus status / quit for recovery.
// The client never sends stars, score or accuracy; the server replays `events` and answers with the result.

/// A frozen run plan from `POST /v1/challenge/chapters/{chapterNo}/levels/{levelNo}/runs` (`status = issued`).
/// Also returned as `run` by the status route while a run is still open.
struct ChallengeRunPlan: Codable, Equatable {
    let runId: String
    var status: String? = nil
    let gameMode: String
    let chapterNo: Int
    let levelNo: Int
    let policyVersion: String
    var contentVersion: Int? = nil
    let explanationLocale: String?
    let goalMatches: Int
    let visiblePairs: Int
    let timeLimitMs: Int
    /// A meaning (same `word`) matched correctly can't come back on the board for this many correct matches.
    let minMatchesBetweenRepeats: Int
    let starCriteria: ChallengeStarCriteria
    let boardSeed: String
    var expiresAt: Date? = nil
    /// The reveal queue, exactly `goalMatches` long. A meaning may appear twice, each time with new IDs.
    let pairs: [ChallengePairOccurrence]
    /// Display-only rule for the live score, frozen with the plan. Nil only for plans issued before the backend sent it,
    /// and then the live score stays hidden.
    var score: ChallengeScoreRule? = nil

    static let matchMadness = "match_madness"
}

/// One star is any clear. Two and three need both their time and their mistake bound.
struct ChallengeStarCriteria: Codable, Equatable {
    struct Tier: Codable, Equatable {
        let maxElapsedMs: Int
        let maxMistakes: Int
    }

    let two: Tier
    let three: Tier
}

/// One pair occurrence in the queue.
struct ChallengePairOccurrence: Codable, Equatable, Identifiable {
    let pairId: String
    let wordTileId: String
    let meaningTileId: String
    let word: String
    let meaning: String

    var id: String { pairId }
}

/// The plan's `score`: each correct pair `match + streakStep × min(combo, maxStreakSteps)` (combo counting the pair
/// just matched), each mistake `−mistake`, a clear adds `perSecondLeft × whole seconds left`; only the total is clamped at 0.
struct ChallengeScoreRule: Codable, Equatable {
    let match: Int
    let streakStep: Int
    let maxStreakSteps: Int
    let mistake: Int
    var perSecondLeft: Int? = nil

    func points(forCombo combo: Int) -> Int {
        match + streakStep * min(max(combo, 0), maxStreakSteps)
    }

    func clearBonus(timeLimitMs: Int, elapsedMs: Int) -> Int {
        (perSecondLeft ?? 0) * (max(timeLimitMs - elapsedMs, 0) / 1000)
    }
}

/// One complete two-tile attempt, right or wrong. Tap selections alone are never sent.
struct MatchAttemptEvent: Codable, Equatable {
    let seq: Int
    let type: String
    let elapsedMs: Int
    let wordTileId: String
    let meaningTileId: String

    init(seq: Int, elapsedMs: Int, wordTileId: String, meaningTileId: String) {
        self.seq = seq
        self.type = "match"
        self.elapsedMs = elapsedMs
        self.wordTileId = wordTileId
        self.meaningTileId = meaningTileId
    }
}

enum ChallengeEndedReason: String, Codable {
    case goalReached = "goal_reached"
    case timeUp = "time_up"
    case quit
}

/// `POST /v1/challenge/runs/{runId}/commit`. Encoded once; a retry sends the same bytes (the server is idempotent
/// on an identical body and answers `CHALLENGE_COMMIT_CONFLICT` to a different one).
struct ChallengeCommitBody: Codable, Equatable {
    let events: [MatchAttemptEvent]
    let endedReason: ChallengeEndedReason
    let endedElapsedMs: Int

    func encoded() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(self)
    }
}

/// The commit response; also `response` in status and in the quit of a started run.
struct ChallengeCommitResponse: Decodable, Equatable {
    enum NextAction: String, Decodable {
        case playNextLevel = "play_next_level"
        case openMap = "open_map"
        case learnMore = "learn_more"
        case retry
        case unknown

        init(from decoder: Decoder) throws {
            self = NextAction(rawValue: try decoder.singleValueContainer().decode(String.self)) ?? .unknown
        }
    }

    var runId: String? = nil
    let result: ChallengeRunResult
    let unlock: ChallengeUnlock?
    let nextAction: NextAction?
}

/// The authoritative outcome of a committed run.
struct ChallengeRunResult: Decodable, Equatable {
    enum Outcome: String, Decodable {
        case cleared, failed, quit, unknown

        init(from decoder: Decoder) throws {
            self = Outcome(rawValue: try decoder.singleValueContainer().decode(String.self)) ?? .unknown
        }
    }

    let outcome: Outcome
    let starsThisRun: Int
    let bestStars: Int
    let correctMatches: Int
    let mistakes: Int
    let longestCombo: Int
    let elapsedMs: Int
    let score: Int
    let bestScore: Int
}

struct ChallengeUnlock: Decodable, Equatable {
    enum Kind: String, Decodable {
        /// First clear of a level: the next level of the chapter opened.
        case level
        /// First clear of the last level, and the next chapter has enough words.
        case chapterReady = "chapter_ready"
        /// First clear of the last level, but the next chapter needs more words.
        case needsVocabulary = "needs_vocabulary"
        case none
        case unknown

        init(from decoder: Decoder) throws {
            self = Kind(rawValue: try decoder.singleValueContainer().decode(String.self)) ?? .unknown
        }
    }

    let kind: Kind
    let chapterNo: Int?
    let levelNo: Int?
    let eligibleNewCount: Int?
    let requiredNewCount: Int?
}

/// `GET /v1/challenge/runs/{runId}/status`.
struct ChallengeRunStatus: Decodable, Equatable {
    enum Status: String, Decodable {
        case issued, started, committed, abandoned, expired, unknown

        init(from decoder: Decoder) throws {
            self = Status(rawValue: try decoder.singleValueContainer().decode(String.self)) ?? .unknown
        }
    }

    let runId: String
    let status: Status
    var chapterNo: Int? = nil
    var levelNo: Int? = nil
    /// The commit response, once committed.
    let response: ChallengeCommitResponse?
    /// The frozen plan while the run is still open.
    var run: ChallengeRunPlan? = nil
}

/// Error codes the challenge routes answer with (§12.7).
enum ChallengeErrorCode {
    static let levelLocked = "CHALLENGE_LEVEL_LOCKED"
    static let runNotFound = "CHALLENGE_RUN_NOT_FOUND"
    static let runActive = "CHALLENGE_RUN_ACTIVE"
    static let runNotStarted = "CHALLENGE_RUN_NOT_STARTED"
    static let commitConflict = "CHALLENGE_COMMIT_CONFLICT"
    static let notEnoughVocabulary = "CHALLENGE_NOT_ENOUGH_VOCABULARY"
    static let contentUnavailable = "CHALLENGE_CONTENT_UNAVAILABLE"
    static let runExpired = "CHALLENGE_RUN_EXPIRED"
    static let invalidEvents = "CHALLENGE_INVALID_EVENTS"
}
