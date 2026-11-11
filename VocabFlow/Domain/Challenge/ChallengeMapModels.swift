import Foundation

// Wire models for `GET /v1/me/challenge-map` (vocab-backend `docs/FRONTEND_FLOW.md` §12.1).
// Unknown enum values decode to `.unknown` instead of failing the whole map, so a newer server state renders as a
// neutral, non-playable node rather than an error screen.

/// The whole Challenge Map. The backend alone decides every state: the client never unlocks anything by counting
/// words itself.
struct ChallengeMap: Decodable, Equatable {
    var configVersion: String? = nil
    var gameMode: String? = nil
    /// Materialized chapters, oldest first.
    let chapters: [ChallengeChapter]
    /// The chapter after the last materialized one (`chapterNo` 1 when there is none yet).
    let nextChapter: ChallengeChapterPreview?
    /// Where the map scrolls to first; nil when nothing is playable.
    let currentNode: ChallengeNodeRef?
    /// `scope_exhausted` when Daily has no new words left to grow the next chapter; nil otherwise or from an older backend.
    var newWordsBlockedReason: NewWordReason? = nil

    var totalStars: Int { chapters.reduce(0) { $0 + $1.starsEarned } }
    /// The earliest chapter not cleared yet: only it can be played forward.
    var openChapter: ChallengeChapter? { chapters.first { $0.state != .completed } }
}

struct ChallengeNodeRef: Codable, Equatable, Hashable {
    let chapterNo: Int
    let levelNo: Int
}

struct ChallengeChapter: Decodable, Equatable, Identifiable {
    enum State: String, Decodable {
        case active, completed
        /// Some words were removed and nothing learned can replace them: point the learner to Daily.
        case contentUnavailable = "content_unavailable"
        case unknown

        init(from decoder: Decoder) throws {
            self = State(rawValue: try decoder.singleValueContainer().decode(String.self)) ?? .unknown
        }
    }

    /// Minted by the server when the chapter materializes.
    let id: String
    let chapterNo: Int
    let state: State
    /// The meaning language the chapter's words were frozen in (e.g. "vi-VN").
    let explanationLocale: String?
    var coreMeaningCount: Int? = nil
    var reviewMeaningCount: Int? = nil
    let starsEarned: Int
    let maxStars: Int
    let levels: [ChallengeLevel]
}

struct ChallengeLevel: Decodable, Equatable, Identifiable {
    enum State: String, Decodable {
        case locked, available, cleared, unknown

        init(from decoder: Decoder) throws {
            self = State(rawValue: try decoder.singleValueContainer().decode(String.self)) ?? .unknown
        }
    }

    static let maxStars = 3

    let levelNo: Int
    let state: State
    let bestStars: Int
    /// 0 until the level has been cleared.
    let bestScore: Int
    /// The level's goal under the current policy, for the sheet before a run exists. A run's plan has the final say.
    var goalMatches: Int? = nil
    var visiblePairs: Int? = nil
    var timeLimitMs: Int? = nil
    var starCriteria: ChallengeStarCriteria? = nil

    var id: Int { levelNo }
    var isPlayable: Bool { state == .available || state == .cleared }
}

struct ChallengeChapterPreview: Decodable, Equatable {
    enum State: String, Decodable {
        /// The current chapter isn't cleared yet.
        case locked
        case needsVocabulary = "needs_vocabulary"
        /// Playing its Level 1 materializes it.
        case ready
        case unknown

        init(from decoder: Decoder) throws {
            self = State(rawValue: try decoder.singleValueContainer().decode(String.self)) ?? .unknown
        }
    }

    let chapterNo: Int
    let state: State
    /// Eligible, unallocated meanings counted towards this chapter. Not the My Words count.
    let eligibleNewCount: Int
    let requiredNewCount: Int

    var remainingNewCount: Int { max(requiredNewCount - eligibleNewCount, 0) }
}

// MARK: - Home summary

/// What the Home card shows, derived from the server map only.
enum ChallengeHomeSummary: Equatable {
    /// Not enough eligible words for the first chapter.
    case notYetEligible(eligible: Int, required: Int)
    /// A chapter can be entered; nothing played in it yet.
    case chapterReady(chapterNo: Int)
    case inProgress(chapterNo: Int, levelNo: Int, earnedStars: Int, maxStars: Int)
    /// Every chapter is cleared and the next needs more words.
    case chapterComplete(chapterNo: Int, earnedStars: Int, maxStars: Int, nextEligible: Int, nextRequired: Int)
    /// The open chapter lost words that can't be replaced yet. Stars are kept.
    case contentUnavailable(chapterNo: Int, earnedStars: Int, maxStars: Int)

    init?(map: ChallengeMap) {
        if let open = map.openChapter {
            if open.state == .contentUnavailable {
                self = .contentUnavailable(chapterNo: open.chapterNo, earnedStars: open.starsEarned, maxStars: open.maxStars)
                return
            }
            let level = map.currentNode.flatMap { $0.chapterNo == open.chapterNo ? $0.levelNo : nil }
                ?? open.levels.first { $0.state == .available }?.levelNo
                ?? 1
            self = .inProgress(chapterNo: open.chapterNo, levelNo: level, earnedStars: open.starsEarned, maxStars: open.maxStars)
            return
        }
        if let next = map.nextChapter, next.state == .ready {
            self = .chapterReady(chapterNo: next.chapterNo)
            return
        }
        let next = map.nextChapter
        if let last = map.chapters.last {
            self = .chapterComplete(
                chapterNo: last.chapterNo,
                earnedStars: last.starsEarned,
                maxStars: last.maxStars,
                nextEligible: next?.eligibleNewCount ?? 0,
                nextRequired: next?.requiredNewCount ?? 0
            )
        } else if let next {
            self = .notYetEligible(eligible: next.eligibleNewCount, required: next.requiredNewCount)
        } else {
            return nil
        }
    }
}
