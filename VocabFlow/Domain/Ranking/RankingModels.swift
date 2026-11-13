import Foundation
import SwiftUI

// Wire models for LP, lifetime Tier and the weekly ranking: vocab-backend/docs/FRONTEND_FLOW.md §14.
// Every field the older backend lacks is optional, so a server without ranking still decodes.

/// Stable server ids; names, stories and art live here on the client (spec §3.2).
enum TierKey: String, LenientEnum, CaseIterable {
    case firstSteps = "first_steps"
    case inMotion = "in_motion"
    case buildingUp = "building_up"
    case steadyEffort = "steady_effort"
    case committed
    case dedicated
    case lastingMark = "lasting_mark"
    case unknown
    static let fallback = TierKey.unknown
}

struct TierBadge: Decodable, Equatable {
    let level: Int
    /// Nil before the first Tier: never shown as "Tier 0".
    let key: TierKey?
}

struct NextTier: Decodable, Equatable {
    let level: Int
    var key: TierKey? = nil
    let minLifetimeLP: Int
    let minLifetimeActiveDays: Int
    /// Only in `GET /me/tier` and `/me/ranking`; the commit response leaves them out.
    var remainingLP: Int? = nil
    var remainingActiveDays: Int? = nil
}

/// The light Tier figures `GET /me` carries for Profile.
struct TierSummary: Decodable, Equatable {
    let level: Int
    let key: TierKey?
    let lifetimeLP: Int
    let lifetimeActiveDays: Int
}

struct TierMilestone: Decodable, Equatable, Identifiable {
    let level: Int
    let key: TierKey?
    let unlockedAt: Date
    var id: Int { level }
}

/// `GET /me/tier`.
struct TierDetail: Decodable, Equatable {
    let level: Int
    let key: TierKey?
    let lifetimeLP: Int
    let lifetimeActiveDays: Int
    let nextTier: NextTier?
    var minQualifiedDayLP: Int? = nil
    let milestones: [TierMilestone]

    var summary: TierSummary { TierSummary(level: level, key: key, lifetimeLP: lifetimeLP, lifetimeActiveDays: lifetimeActiveDays) }
}

// MARK: - Commit

struct LPBreakdown: Decodable, Equatable {
    var newMeaningLP = 0
    var dueReviewLP = 0
    var extraPracticeLP = 0

    static func + (lhs: LPBreakdown, rhs: LPBreakdown) -> LPBreakdown {
        LPBreakdown(newMeaningLP: lhs.newMeaningLP + rhs.newMeaningLP, dueReviewLP: lhs.dueReviewLP + rhs.dueReviewLP,
                    extraPracticeLP: lhs.extraPracticeLP + rhs.extraPracticeLP)
    }
}

struct CommitLP: Decodable, Equatable {
    let earned: Int
    var breakdown: LPBreakdown? = nil
    let weeklyLP: Int
    let lifetimeLP: Int
}

struct TierUp: Decodable, Equatable {
    let level: Int
    let key: TierKey?
    let unlockedAt: Date
}

struct CommitTier: Decodable, Equatable {
    let level: Int
    let key: TierKey?
    let lifetimeActiveDays: Int
    let tierUps: [TierUp]
    let nextTier: NextTier?
}

struct CommitRanking: Decodable, Equatable {
    let weeklyLP: Int
    let listed: Bool
}

/// LP and Tier across one session screen. A daily lesson can commit twice (review, then new words),
/// so the results add both commits up and keep the latest totals.
struct SessionEffort: Equatable {
    var earned = 0
    var breakdown = LPBreakdown()
    var lifetimeLP = 0
    var tier: CommitTier?
    var tierUps: [TierUp] = []

    mutating func add(lp: CommitLP, tier: CommitTier?) {
        earned += lp.earned
        breakdown = breakdown + (lp.breakdown ?? LPBreakdown())
        lifetimeLP = lp.lifetimeLP
        if let tier {
            self.tier = tier
            tierUps += tier.tierUps
        }
    }

    /// The highest Tier this session unlocked: the one to celebrate.
    var celebratedTierUp: TierUp? { tierUps.max { $0.level < $1.level } }
}

// MARK: - Ranking

enum RankingPositionKind: String, LenientEnum {
    case rank, percentile, unranked
    static let fallback = RankingPositionKind.unranked
}

struct RankingPosition: Decodable, Equatable {
    let kind: RankingPositionKind
    let rank: Int?
    let percentile: Int?
    var estimated: Bool? = nil
}

/// `GET /me/ranking`.
struct MyRanking: Decodable, Equatable {
    let weekStart: String
    let weekEndsAt: Date
    let weeklyLP: Int
    let listed: Bool
    let position: RankingPosition?
    let tier: TierDetailSummary
    /// Listed learners this week ("#42 / 120"). Not sent by the backend yet — see memory ranking-ui-mockup.
    var totalListed: Int? = nil
}

/// The Tier block inside `/me/ranking`: like `TierDetail` without milestones.
struct TierDetailSummary: Decodable, Equatable {
    let level: Int
    let key: TierKey?
    let lifetimeLP: Int
    let lifetimeActiveDays: Int
    let nextTier: NextTier?
}

struct RankingTierThreshold: Decodable, Equatable {
    let level: Int
    let key: TierKey?
    let minLifetimeLP: Int
    let minLifetimeActiveDays: Int
}

/// `GET /ranking/meta`.
struct RankingMeta: Decodable, Equatable {
    let weekStart: String
    let weekEndsAt: Date
    let rankingEnabled: Bool
    let tiers: [RankingTierThreshold]
    var minQualifiedDayLP: Int? = nil
    let avatarKeys: [String]
    let reportReasons: [String]
    var usernameChangeDays: Int? = nil
}

enum LeaderboardView: String {
    case top, around
}

struct LeaderboardRow: Decodable, Equatable, Identifiable {
    let rank: Int?
    let username: String
    let avatarKey: String
    let weeklyLP: Int
    let lifetimeTier: TierBadge
    let isMe: Bool
    var id: String { username }
}

struct Leaderboard: Decodable, Equatable {
    let weekStart: String
    let weekEndsAt: Date
    let rows: [LeaderboardRow]
}

struct RankingWeek: Decodable, Equatable, Identifiable {
    let weekStart: String
    let weeklyLP: Int
    let rank: Int?
    var id: String { weekStart }
}

struct RankingHistory: Decodable, Equatable {
    struct CurrentWeek: Decodable, Equatable {
        let weekStart: String
        let weeklyLP: Int
    }

    let currentWeek: CurrentWeek
    let weeks: [RankingWeek]
}

/// `POST /ranking/reports` reasons; the server's list in `RankingMeta.reportReasons` decides which show.
enum ReportReason: String, CaseIterable, Identifiable, Encodable {
    case offensiveName = "offensive_name"
    case impersonation
    case suspiciousActivity = "suspicious_activity"
    case other
    var id: String { rawValue }
}

/// `PUT /me/profile` is strict: nil fields are omitted.
struct PublicProfileUpdate: Encodable, Equatable {
    var username: String?
    var avatarKey: String?
}

struct PublicProfile: Decodable, Equatable {
    let username: String
    let avatarKey: String
    let usernameChangeAvailableAt: Date?
}

// MARK: - Presentation

extension TierKey {
    var name: LocalizedStringKey {
        switch self {
        case .firstSteps: "First Steps"
        case .inMotion: "In Motion"
        case .buildingUp: "Building Up"
        case .steadyEffort: "Steady Effort"
        case .committed: "Committed"
        case .dedicated: "Dedicated"
        case .lastingMark: "Lasting Mark"
        case .unknown: "New milestone"
        }
    }

    /// For strings that can't take a `LocalizedStringKey` (VoiceOver values, formatted text).
    var localizedName: String {
        switch self {
        case .firstSteps: String(localized: "First Steps", bundle: .appLanguage)
        case .inMotion: String(localized: "In Motion", bundle: .appLanguage)
        case .buildingUp: String(localized: "Building Up", bundle: .appLanguage)
        case .steadyEffort: String(localized: "Steady Effort", bundle: .appLanguage)
        case .committed: String(localized: "Committed", bundle: .appLanguage)
        case .dedicated: String(localized: "Dedicated", bundle: .appLanguage)
        case .lastingMark: String(localized: "Lasting Mark", bundle: .appLanguage)
        case .unknown: String(localized: "New milestone", bundle: .appLanguage)
        }
    }

    /// Recognises the effort; never claims a level of English or words remembered (spec §3.2).
    var story: LocalizedStringKey {
        switch self {
        case .firstSteps: "You’ve started putting effort into your learning journey."
        case .inMotion: "Your sessions are adding up into your first stretch of progress."
        case .buildingUp: "Small sessions have added up to a clear achievement."
        case .steadyEffort: "You’ve learned on many different days, at your own pace."
        case .committed: "You’ve put in real effort and keep building this journey."
        case .dedicated: "A milestone for the long stretch you’ve given to learning."
        case .lastingMark: "Your effort has become a lasting mark on your journey with Syll."
        case .unknown: "Keep going at your own pace."
        }
    }

    /// Stand-in art until the Tier visuals are drawn (spec gate P4).
    var systemImage: String {
        switch self {
        case .firstSteps: "shoeprints.fill"
        case .inMotion: "wind"
        case .buildingUp: "square.stack.3d.up.fill"
        case .steadyEffort: "calendar"
        case .committed: "flame.fill"
        case .dedicated: "mountain.2.fill"
        case .lastingMark: "seal.fill"
        case .unknown: "sparkles"
        }
    }

    var mood: SyllieMood {
        switch self {
        case .firstSteps, .inMotion: .happy
        case .buildingUp, .steadyEffort: .happyPuff
        case .committed, .dedicated, .lastingMark: .proud
        case .unknown: .happy
        }
    }
}

/// Avatar keys come from the server's allowlist; unknown keys still draw something.
enum AvatarStyle {
    private static let palette: [(String, Color, String)] = [
        ("syllie_sunny", .reward, "sun.max.fill"),
        ("syllie_sleepy", .selectedSurface, "moon.zzz.fill"),
        ("syllie_curious", .successSurface, "magnifyingglass"),
        ("syllie_brave", .errorSurface, "shield.fill"),
        ("syllie_calm", .selectedSurface, "leaf.fill"),
        ("syllie_cheerful", .reward, "face.smiling.inverse"),
        ("syllie_thinker", .neutralSurface, "lightbulb.fill"),
        ("syllie_explorer", .successSurface, "map.fill"),
        ("syllie_reader", .selectedSurface, "book.fill"),
        ("syllie_artist", .errorSurface, "paintpalette.fill"),
        ("syllie_sporty", .successSurface, "figure.run"),
        ("syllie_starry", .reward, "star.fill"),
    ]

    static func background(_ key: String) -> Color { palette.first { $0.0 == key }?.1 ?? .neutralSurface }
    static func symbol(_ key: String) -> String { palette.first { $0.0 == key }?.2 ?? "person.fill" }
}
