import Foundation

// MARK: - Auth

struct AuthSession: Decodable, Equatable {
    struct User: Decodable, Equatable {
        let id: String
        let email: String?
    }

    let accessToken: String
    let refreshToken: String
    let expiresIn: Int
    let user: User
}

struct SignupResult: Decodable, Equatable {
    let session: AuthSession?
    let confirmationRequired: Bool
}

// MARK: - Profile

enum CEFRLevel: String, Codable, CaseIterable, Identifiable {
    case a1 = "A1", a2 = "A2", b1 = "B1", b2 = "B2", c1 = "C1", c2 = "C2"

    var id: String { rawValue }
}

struct UserSettings: Decodable, Equatable {
    let explanationLocale: String
    let uiLocale: String
    let timeZone: String
    let dailyNewWordGoal: Int
    /// Sessions per checkpoint challenge (a Journey segment). Nil from a backend that predates it.
    var weeklySessionGoal: Int? = nil
    /// Opt-in: fewer new words while the review backlog is large. Nil from an older backend.
    var autoBalanceNewWords: Bool? = nil
    /// Public on the weekly leaderboard. Off until the learner opts in; nil from a backend without ranking.
    var leaderboardVisible: Bool? = nil
    /// Reviews per daily session the learner chose; nil follows the new-word goal (or an older backend).
    var reviewsPerSession: Int? = nil
}

struct LearningScope: Codable, Equatable {
    let collectionId: String
    let topicIds: [String]
}

struct UserProfile: Decodable, Equatable {
    let id: String
    let proficiencyLevel: CEFRLevel?
    let learningLevel: CEFRLevel?
    let settings: UserSettings
    let scope: LearningScope?
    /// Collections whose words the learner stopped reviewing. Nil from an older backend.
    var reviewPauses: [ReviewPause]? = nil
    /// Public identity and lifetime Tier (FRONTEND_FLOW §14). Nil from a backend without ranking.
    var username: String? = nil
    var avatarKey: String? = nil
    /// Nil means the name can change now.
    var usernameChangeAvailableAt: Date? = nil
    var rankingIntroSeen: Bool? = nil
    var tierSummary: TierSummary? = nil

    var hasFinishedOnboarding: Bool { proficiencyLevel != nil && scope != nil }
}

/// `PUT /me/settings` is strict: nil fields are omitted from the body.
struct SettingsUpdate: Encodable, Equatable {
    var explanationLocale: String?
    var uiLocale: String?
    var timeZone: String?
    var dailyNewWordGoal: Int?
    /// The number of learning days a week; the backend sizes each Journey segment by it.
    var weeklySessionGoal: Int?
    var autoBalanceNewWords: Bool?
    /// Only from an explicit "Join" or the Settings toggle, never from seeing the intro.
    var leaderboardVisible: Bool?
    /// `.some(nil)` is sent as `null`: back to following the new-word goal.
    var reviewsPerSession: Int?? = nil
}

struct ReviewPause: Decodable, Equatable {
    let collectionId: String
}

// MARK: - Placement test

/// Always a text `select`. Unlike a practice task, option ids are UUID strings and there is no answer key:
/// only the backend scores it. Questions and options keep the backend's order.
struct PlacementQuestion: Decodable, Equatable, Identifiable {
    struct Prompt: Decodable, Equatable {
        let text: String
    }

    struct Option: Decodable, Equatable, Identifiable {
        let id: String
        let text: String
    }

    let id: String
    let prompt: Prompt
    let question: String?
    let options: [Option]
}

struct PlacementAnswer: Encodable, Equatable {
    let questionId: String
    /// Nil means the learner skipped it because they don't know.
    let optionId: String?

    private enum CodingKeys: String, CodingKey {
        case questionId, optionId
    }

    /// Spelled out because synthesized encoding would omit nil, and the contract sends an explicit null.
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(questionId, forKey: .questionId)
        try container.encode(optionId, forKey: .optionId)
    }
}

/// The backend has already saved this level by the time it answers.
struct PlacementResult: Decodable, Equatable {
    let proficiencyLevel: CEFRLevel
    let correctCount: Int
    let totalCount: Int
}

// MARK: - Catalog

/// `learnedMeanings` / `totalMeanings` count distinct meanings; nil from an older backend.
struct CatalogTopic: Decodable, Equatable {
    let id: String
    let slug: String
    let title: String
    let description: String?
    var learnedMeanings: Int? = nil
    var totalMeanings: Int? = nil
}

struct CatalogCollection: Decodable, Equatable {
    let id: String
    let slug: String
    let title: String
    let description: String?
    let topics: [CatalogTopic]
    var learnedMeanings: Int? = nil
    var totalMeanings: Int? = nil
}

// MARK: - Home and words

struct LearnHome: Decodable, Equatable {
    let dueCount: Int
    /// The number of open checkpoint challenges.
    let checkpointAvailable: Int
    /// Sessions counted towards the next challenge. Returns to 0 when a challenge opens.
    let checkpointSessionsDone: Int
    let checkpointSessionsRequired: Int
    let learnedTotal: Int
    /// Nil from a backend that predates scope completion.
    var scope: ScopeState? = nil
    var reviewLoad: ReviewLoad? = nil

    var checkpointProgress: Double {
        guard checkpointSessionsRequired > 0 else { return 0 }
        return min(Double(checkpointSessionsDone) / Double(checkpointSessionsRequired), 1)
    }
}

/// Decodes an unknown raw value to `fallback`, so a new server value never fails a whole response.
protocol LenientEnum: RawRepresentable, Decodable where RawValue == String {
    static var fallback: Self { get }
}

extension LenientEnum {
    init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = Self(rawValue: raw) ?? .fallback
    }
}

enum ScopeStatus: String, LenientEnum {
    case ok, low, exhausted
    static let fallback = ScopeStatus.ok
}

/// How many new words the scope still holds (`R`) and how many words the learner added (`C`).
struct ScopeState: Decodable, Equatable {
    struct TopicRemaining: Decodable, Equatable {
        let topicId: String
        let remainingNewMeanings: Int
        let totalMeanings: Int
    }

    let status: ScopeStatus
    let remainingNewMeanings: Int
    let pendingCustomMeanings: Int
    let sessionsLeftEstimate: Int?
    let topics: [TopicRemaining]
}

/// Why a daily session has fewer new words than the goal (`newWordReason` and `withheldReason`).
enum NewWordReason: String, LenientEnum {
    case goal
    case userOverride = "user_override"
    case autoBalanced = "auto_balanced"
    case checkpointGate = "checkpoint_gate"
    case scopeLimited = "scope_limited"
    case scopeExhausted = "scope_exhausted"
    case reviewOnly = "review_only"
    case unknown
    static let fallback = NewWordReason.unknown
}

enum NewWordOverrideMode: String, Codable, Equatable {
    case untilDate = "until_date"
    case untilBacklogClear = "until_backlog_clear"
}

/// A temporary lower number of new words the learner chose.
struct NewWordOverride: Decodable, Equatable {
    let value: Int
    let mode: NewWordOverrideMode
    let until: Date?
}

struct ReviewLoad: Decodable, Equatable {
    let backlog: Int
    let dueCap: Int
    let effectiveNewPerSession: Int
    let newWordReason: NewWordReason
    let override: NewWordOverride?
    let autoBalance: Bool
    /// The server's "ask now" flag; the app still shows it at most once per launch and never mid-session.
    let promptChoice: Bool

    /// Above this, Home shows the backlog line and offers an extra review session.
    static let statusThreshold = 10
}

struct CheckpointChallenge: Decodable, Equatable, Identifiable {
    let id: String
    let sequence: Int
    let createdAt: Date
    let meaningCount: Int
}

enum SkillStatus: String, Decodable {
    case demonstrated, verified
    case notVerified = "not_verified"
}

enum SkillIssue: String, Decodable {
    case failed, assisted
}

struct SkillState: Decodable, Equatable {
    let status: SkillStatus
    let needsPractice: Bool
    let issue: SkillIssue?
}

struct MeaningSkills: Decodable, Equatable {
    let reading: SkillState
    let writing: SkillState
    /// Absent when the meaning has no pronunciation.
    let listening: SkillState?
    let speaking: SkillState?
}

struct WordMeaning: Decodable, Equatable {
    struct Sense: Decodable, Equatable {
        let partOfSpeech: String
        let text: String
        let ipa: String?
        var definition: String?
        var audio: AudioClip?
        var examples: [LearnCard.Example]?
    }

    let meaningId: String
    let meaning: Sense
    let learnedAt: Date?
    let nextReviewAt: Date?
}

/// One library row. Skill states are not part of it: they load with `WordDetail` when a word opens.
struct WordProgress: Decodable, Equatable, Identifiable {
    let wordId: String
    let lemma: String
    /// Learned meanings only; `meaningCount` counts every meaning the word has. Absent from older servers.
    let meanings: [WordMeaning]
    var meaningCount: Int? = nil

    var id: String { wordId }
    var meaningText: String { meanings.map(\.meaning.text).joined(separator: "; ") }
    var ipa: String? { meanings.lazy.compactMap(\.meaning.ipa).first }
}

/// Library-wide figures, independent of paging and search.
struct WordStats: Decodable, Equatable {
    let learnedWords: Int
    let needPracticeWords: Int
}

/// Every meaning of the word, including the ones not learned yet (`learnedAt == nil`).
struct WordDetail: Decodable, Equatable {
    struct Meaning: Decodable, Equatable {
        let meaningId: String
        let meaning: WordMeaning.Sense
        let learnedAt: Date?
        let skills: MeaningSkills
    }

    let wordId: String
    let lemma: String
    let meanings: [Meaning]
}

/// One due word, shown before a session's review tasks.
struct ReviewWord: Equatable, Identifiable {
    let id: String
    let lemma: String
    let dueAt: Date
    /// The topic the word is labelled with; nil from the library fallback.
    var topic: String? = nil

    /// A daily plan reviews the longest-overdue meanings up to this many.
    static let sessionCap = 10

    /// Mirrors the planner's pick. Plans don't say which words their tasks test, so this is a best match:
    /// the library also holds due meanings the planner skips, such as ones outside the active topics.
    /// The cap counts meanings, so a word with two due meanings still appears once.
    static func due(in words: [WordProgress], on date: Date) -> [ReviewWord] {
        let due = words.flatMap { word in
            word.meanings.compactMap { meaning -> ReviewWord? in
                guard let dueAt = meaning.nextReviewAt, dueAt <= date else { return nil }
                return ReviewWord(id: word.wordId, lemma: word.lemma, dueAt: dueAt)
            }
        }
        var seen = Set<String>()
        return due.sorted { $0.dueAt < $1.dueAt }.prefix(sessionCap).filter { seen.insert($0.id).inserted }
    }
}

// MARK: - API surface

/// Everything the app asks of the backend. Stores depend on this, so tests and previews can stub it.
protocol VocabAPI: Sendable {
    func hasStoredSession() async -> Bool
    func signUp(email: String, password: String) async throws -> SignupResult
    func logIn(email: String, password: String) async throws
    func logIn(googleIDToken: String, nonce: String?) async throws
    func logIn(appleIDToken: String, nonce: String?) async throws
    /// Emails a reset-password link. Succeeds whether or not the address has an account.
    func requestPasswordReset(email: String) async throws
    /// Checks the emailed reset code, sets the new password and signs in.
    func resetPassword(email: String, code: String, newPassword: String) async throws
    func changePassword(current: String, new: String) async throws
    func signOut() async
    /// Permanent. On failure nothing was deleted.
    func deleteAccount() async throws

    func profile() async throws -> UserProfile
    func updateLevels(_ level: CEFRLevel) async throws
    /// Empty when there isn't enough content yet; the learner then picks a level by hand.
    func placementTest() async throws -> [PlacementQuestion]
    func submitPlacementTest(_ answers: [PlacementAnswer]) async throws -> PlacementResult
    func updateSettings(_ settings: SettingsUpdate) async throws
    func updateScope(_ scope: LearningScope) async throws
    func catalog() async throws -> [CatalogCollection]

    func learnHome() async throws -> LearnHome
    /// Records that the review-load choice was shown, so other devices don't ask again.
    func acknowledgeReviewLoad(backlog: Int) async throws
    /// `until` nil with `untilDate` lets the server pick the end of the learner's Sunday.
    func setNewWordOverride(value: Int, mode: NewWordOverrideMode, until: Date?) async throws -> NewWordOverride
    func clearNewWordOverride() async throws
    func setReviewPaused(collectionID: String, paused: Bool) async throws
    func checkpointChallenges() async throws -> [CheckpointChallenge]
    /// The first page (no `before`) holds the future previews, the current segment and `historyLimit` older ones;
    /// `before` (a `nextHistoryCursor`) pages through older history only.
    func journey(historyLimit: Int, before: Int?) async throws -> Journey
    /// `query` searches on the server, across the English word and its meanings.
    func words(limit: Int, offset: Int, query: String?) async throws -> [WordProgress]
    func wordStats() async throws -> WordStats
    func wordDetail(id: String) async throws -> WordDetail

    func lookupCustomWord(_ query: CustomWordQuery) async throws -> CustomWordLookup
    func addCustomWord(_ addition: CustomWordAddition) async throws -> CustomWordAdded
    func customWords() async throws -> [CustomWord]
    func removeCustomWord(meaningID: String) async throws
    func overrideCustomWord(meaningID: String, edits: CustomWordEdits) async throws
    func clearCustomWordOverride(meaningID: String) async throws

    func planSession(_ request: PlanRequest) async throws -> SessionPlan
    func assessRecording(sessionID: String, taskID: String, audio: RecordedAudio) async throws -> RecordingAssessment
    /// `body` is sent as is: a retried commit must repeat the first attempt's bytes.
    func commitSession(sessionID: String, body: Data) async throws -> CommitResponse
    func commitStatus(sessionID: String) async throws -> CommitStatus

    // Challenge (Match Madness). Separate from learning sessions: nothing here changes SRS or Daily.
    func challengeMap() async throws -> ChallengeMap
    /// Freezes a full run plan (`status = issued`). The clock does not start yet.
    func issueChallengeRun(chapterNo: Int, levelNo: Int) async throws -> ChallengeRunPlan
    /// Idempotent. The client starts its clock only after this answers.
    func startChallengeRun(runID: String) async throws
    /// `body` is sent as is: a retried commit must repeat the first attempt's bytes.
    func commitChallengeRun(runID: String, body: Data) async throws -> ChallengeCommitResponse
    func challengeRunStatus(runID: String) async throws -> ChallengeRunStatus
    /// Abandons an issued run, or settles an orphaned started one with 0 stars.
    func quitChallengeRun(runID: String) async throws

    // LP, Tier and the weekly ranking. The leaderboard and reports answer 403 RANKING_DISABLED until launch.
    func rankingMeta() async throws -> RankingMeta
    func myRanking() async throws -> MyRanking
    func tierDetail() async throws -> TierDetail
    func leaderboard(_ view: LeaderboardView) async throws -> Leaderboard
    func rankingHistory(weeks: Int) async throws -> RankingHistory
    func markRankingIntroSeen() async throws
    func updatePublicProfile(_ update: PublicProfileUpdate) async throws -> PublicProfile
    func reportLearner(username: String, reason: ReportReason) async throws
}

/// Older test doubles and previews keep compiling: these calls just fail offline.
extension VocabAPI {
    func acknowledgeReviewLoad(backlog: Int) async throws {}
    func setNewWordOverride(value: Int, mode: NewWordOverrideMode, until: Date?) async throws -> NewWordOverride {
        throw APIError.transport
    }
    func clearNewWordOverride() async throws {}
    func setReviewPaused(collectionID: String, paused: Bool) async throws {}

    func rankingMeta() async throws -> RankingMeta { throw APIError.transport }
    func myRanking() async throws -> MyRanking { throw APIError.transport }
    func tierDetail() async throws -> TierDetail { throw APIError.transport }
    func leaderboard(_ view: LeaderboardView) async throws -> Leaderboard { throw APIError.transport }
    func rankingHistory(weeks: Int) async throws -> RankingHistory { throw APIError.transport }
    func markRankingIntroSeen() async throws {}
    func updatePublicProfile(_ update: PublicProfileUpdate) async throws -> PublicProfile { throw APIError.transport }
    func reportLearner(username: String, reason: ReportReason) async throws {}
}

extension VocabAPI {
    /// The library is ordered by last learned, so anything scanning it for due dates needs every page.
    func allWords(pageSize: Int = 100) async throws -> [WordProgress] {
        var result: [WordProgress] = []
        while true {
            let page = try await words(limit: pageSize, offset: result.count, query: nil)
            result += page
            if page.count < pageSize { return result }
        }
    }
}

struct LiveVocabAPI: VocabAPI {
    let client: APIClient
    /// The commit is idempotent, so it may retry harder than other requests.
    private static let commitRetries = 3
    private static let readRetries = 2
    /// The backend may wait on AI or speech generation, and allows itself about a minute.
    private static let customWordTimeout: TimeInterval = 70

    func hasStoredSession() async -> Bool { await client.hasStoredSession }

    func signUp(email: String, password: String) async throws -> SignupResult {
        let result: SignupResult = try await client.send(
            try post("auth/signup", Credentials(email: email, password: password), requiresAuth: false)
        )
        if let session = result.session {
            await client.store(session)
        }
        return result
    }

    func logIn(email: String, password: String) async throws {
        let session: AuthSession = try await client.send(
            try post("auth/login", Credentials(email: email, password: password), requiresAuth: false)
        )
        await client.store(session)
    }

    func logIn(googleIDToken: String, nonce: String?) async throws {
        let session: AuthSession = try await client.send(
            try post("auth/google", IDTokenCredentials(idToken: googleIDToken, nonce: nonce), requiresAuth: false)
        )
        await client.store(session)
    }

    func logIn(appleIDToken: String, nonce: String?) async throws {
        let session: AuthSession = try await client.send(
            try post("auth/apple", IDTokenCredentials(idToken: appleIDToken, nonce: nonce), requiresAuth: false)
        )
        await client.store(session)
    }

    func requestPasswordReset(email: String) async throws {
        _ = try await client.sendRaw(try post("auth/recover", PasswordReset(email: email), requiresAuth: false))
    }

    func resetPassword(email: String, code: String, newPassword: String) async throws {
        let session: AuthSession = try await client.send(
            try post("auth/recover/verify", ResetVerification(email: email, code: code, password: newPassword), requiresAuth: false)
        )
        await client.store(session)
    }

    func changePassword(current: String, new: String) async throws {
        var request = try post("me/password", PasswordChange(currentPassword: current, newPassword: new))
        request.method = .put
        _ = try await client.sendRaw(request)
    }

    func signOut() async {
        await client.signOut()
    }

    func deleteAccount() async throws {
        _ = try await client.sendRaw(APIRequest(method: .delete, path: "me"))
    }

    func profile() async throws -> UserProfile {
        try await client.send(get("me"))
    }

    func updateLevels(_ level: CEFRLevel) async throws {
        var request = try post("me/levels", Levels(proficiencyLevel: level))
        request.method = .put
        _ = try await client.sendRaw(request)
    }

    func placementTest() async throws -> [PlacementQuestion] {
        let response: PlacementTestResponse = try await client.send(get("me/placement-test"))
        return response.questions
    }

    func submitPlacementTest(_ answers: [PlacementAnswer]) async throws -> PlacementResult {
        try await client.send(try post("me/placement-test", PlacementSubmission(answers: answers)))
    }

    func updateSettings(_ settings: SettingsUpdate) async throws {
        var request = try post("me/settings", settings)
        request.method = .put
        _ = try await client.sendRaw(request)
    }

    func updateScope(_ scope: LearningScope) async throws {
        var request = try post("me/scope", scope)
        request.method = .put
        _ = try await client.sendRaw(request)
    }

    func catalog() async throws -> [CatalogCollection] {
        let response: CatalogResponse = try await client.send(get("catalog/collections"))
        return response.collections
    }

    func learnHome() async throws -> LearnHome {
        try await client.send(get("me/learn-home"))
    }

    func acknowledgeReviewLoad(backlog: Int) async throws {
        _ = try await client.sendRaw(try post("me/review-load/ack", ReviewLoadAck(backlog: backlog)))
    }

    func setNewWordOverride(value: Int, mode: NewWordOverrideMode, until: Date?) async throws -> NewWordOverride {
        var request = try post("me/new-word-override", OverrideRequest(value: value, mode: mode, until: until.map { $0.ISO8601Format() }))
        request.method = .put
        let response: OverrideResponse = try await client.send(request)
        return response.override
    }

    func clearNewWordOverride() async throws {
        _ = try await client.sendRaw(APIRequest(method: .delete, path: "me/new-word-override"))
    }

    func setReviewPaused(collectionID: String, paused: Bool) async throws {
        _ = try await client.sendRaw(APIRequest(method: paused ? .put : .delete, path: "me/review-pauses/\(collectionID)"))
    }

    func checkpointChallenges() async throws -> [CheckpointChallenge] {
        let response: CheckpointResponse = try await client.send(get("me/checkpoint-challenges"))
        return response.challenges
    }

    func journey(historyLimit: Int, before: Int?) async throws -> Journey {
        var request = get("me/journey")
        request.query = [URLQueryItem(name: "historyLimit", value: String(historyLimit))]
        if let before { request.query.append(URLQueryItem(name: "before", value: String(before))) }
        return try await client.send(request)
    }

    func words(limit: Int, offset: Int, query: String?) async throws -> [WordProgress] {
        var request = get("me/words")
        request.query = [
            URLQueryItem(name: "limit", value: String(limit)),
            URLQueryItem(name: "offset", value: String(offset)),
        ]
        if let query, !query.isEmpty {
            request.query.append(URLQueryItem(name: "q", value: query))
        }
        let response: WordsResponse = try await client.send(request)
        return response.words
    }

    func wordStats() async throws -> WordStats {
        try await client.send(get("me/words/stats"))
    }

    func wordDetail(id: String) async throws -> WordDetail {
        try await client.send(get("words/\(id)"))
    }

    /// Not retried here: every generation counts against the learner's daily allowance.
    func lookupCustomWord(_ query: CustomWordQuery) async throws -> CustomWordLookup {
        var request = try post("custom-words/lookup", query)
        request.timeout = Self.customWordTimeout
        return try await client.send(request)
    }

    func addCustomWord(_ addition: CustomWordAddition) async throws -> CustomWordAdded {
        var request = try post("custom-words", addition)
        request.timeout = Self.customWordTimeout
        return try await client.send(request)
    }

    func customWords() async throws -> [CustomWord] {
        let response: CustomWordsResponse = try await client.send(get("custom-words"))
        return response.words
    }

    func removeCustomWord(meaningID: String) async throws {
        _ = try await client.sendRaw(APIRequest(method: .delete, path: "custom-words/\(meaningID)"))
    }

    func overrideCustomWord(meaningID: String, edits: CustomWordEdits) async throws {
        var request = try post("custom-words/\(meaningID)/override", edits)
        request.method = .put
        _ = try await client.sendRaw(request)
    }

    func clearCustomWordOverride(meaningID: String) async throws {
        _ = try await client.sendRaw(APIRequest(method: .delete, path: "custom-words/\(meaningID)/override"))
    }

    func planSession(_ request: PlanRequest) async throws -> SessionPlan {
        try await client.send(try post("sessions/plan", request))
    }

    func assessRecording(sessionID: String, taskID: String, audio: RecordedAudio) async throws -> RecordingAssessment {
        var form = MultipartForm()
        form.addField(name: "taskId", value: taskID)
        form.addFile(name: "audio", filename: "recording.wav", contentType: audio.contentType, data: audio.data)
        var request = APIRequest(method: .post, path: "sessions/\(sessionID)/recording-assess")
        request.body = form.finished()
        request.contentType = form.contentType
        return try await client.send(request)
    }

    func commitSession(sessionID: String, body: Data) async throws -> CommitResponse {
        var request = APIRequest(method: .post, path: "sessions/\(sessionID)/commit")
        request.body = body
        request.retries = Self.commitRetries
        return try await client.send(request)
    }

    func commitStatus(sessionID: String) async throws -> CommitStatus {
        try await client.send(get("sessions/\(sessionID)/commit-status"))
    }

    func challengeMap() async throws -> ChallengeMap {
        try await client.send(get("me/challenge-map"))
    }

    func issueChallengeRun(chapterNo: Int, levelNo: Int) async throws -> ChallengeRunPlan {
        try await client.send(emptyPost("challenge/chapters/\(chapterNo)/levels/\(levelNo)/runs"))
    }

    func startChallengeRun(runID: String) async throws {
        // Idempotent on the server, so it may retry.
        var request = emptyPost("challenge/runs/\(runID)/start")
        request.retries = Self.commitRetries
        _ = try await client.sendRaw(request)
    }

    func commitChallengeRun(runID: String, body: Data) async throws -> ChallengeCommitResponse {
        var request = APIRequest(method: .post, path: "challenge/runs/\(runID)/commit")
        request.body = body
        request.retries = Self.commitRetries
        return try await client.send(request)
    }

    func challengeRunStatus(runID: String) async throws -> ChallengeRunStatus {
        try await client.send(get("challenge/runs/\(runID)/status"))
    }

    func quitChallengeRun(runID: String) async throws {
        _ = try await client.sendRaw(emptyPost("challenge/runs/\(runID)/quit"))
    }

    func rankingMeta() async throws -> RankingMeta {
        try await client.send(get("ranking/meta"))
    }

    func myRanking() async throws -> MyRanking {
        try await client.send(get("me/ranking"))
    }

    func tierDetail() async throws -> TierDetail {
        try await client.send(get("me/tier"))
    }

    func leaderboard(_ view: LeaderboardView) async throws -> Leaderboard {
        var request = get("ranking/leaderboard")
        request.query = [URLQueryItem(name: "view", value: view.rawValue)]
        return try await client.send(request)
    }

    func rankingHistory(weeks: Int) async throws -> RankingHistory {
        var request = get("me/ranking/history")
        request.query = [URLQueryItem(name: "weeks", value: String(weeks))]
        return try await client.send(request)
    }

    func markRankingIntroSeen() async throws {
        _ = try await client.sendRaw(emptyPost("me/ranking/intro-seen"))
    }

    func updatePublicProfile(_ update: PublicProfileUpdate) async throws -> PublicProfile {
        var request = try post("me/profile", update)
        request.method = .put
        return try await client.send(request)
    }

    func reportLearner(username: String, reason: ReportReason) async throws {
        _ = try await client.sendRaw(try post("ranking/reports", LearnerReport(username: username, reason: reason)))
    }

    /// A POST whose body is `{}`.
    private func emptyPost(_ path: String) -> APIRequest {
        var request = APIRequest(method: .post, path: path)
        request.body = Data("{}".utf8)
        return request
    }

    private func get(_ path: String) -> APIRequest {
        APIRequest(method: .get, path: path, retries: Self.readRetries)
    }

    private func post(_ path: String, _ body: some Encodable, requiresAuth: Bool = true) throws -> APIRequest {
        var request = APIRequest(method: .post, path: path, requiresAuth: requiresAuth)
        request.body = try JSONEncoder().encode(body)
        return request
    }

    private struct Credentials: Encodable {
        let email: String
        let password: String
    }

    private struct IDTokenCredentials: Encodable {
        let idToken: String
        let nonce: String?
    }

    private struct PasswordReset: Encodable {
        let email: String
    }

    private struct ResetVerification: Encodable {
        let email: String
        let code: String
        let password: String
    }

    private struct PasswordChange: Encodable {
        let currentPassword: String
        let newPassword: String
    }

    private struct Levels: Encodable {
        let proficiencyLevel: CEFRLevel
    }

    private struct PlacementTestResponse: Decodable {
        let questions: [PlacementQuestion]
    }

    private struct PlacementSubmission: Encodable {
        let answers: [PlacementAnswer]
    }

    private struct CatalogResponse: Decodable {
        let collections: [CatalogCollection]
    }

    private struct ReviewLoadAck: Encodable {
        let backlog: Int
    }

    private struct OverrideRequest: Encodable {
        let value: Int
        let mode: NewWordOverrideMode
        let until: String?
    }

    private struct OverrideResponse: Decodable {
        let override: NewWordOverride
    }

    private struct CheckpointResponse: Decodable {
        let challenges: [CheckpointChallenge]
    }

    private struct WordsResponse: Decodable {
        let words: [WordProgress]
    }

    private struct CustomWordsResponse: Decodable {
        let words: [CustomWord]
    }

    private struct LearnerReport: Encodable {
        let username: String
        let reason: ReportReason
    }
}

/// Answers every call with nothing, for previews and tests that don't exercise the backend.
struct OfflineVocabAPI: VocabAPI {
    func hasStoredSession() async -> Bool { true }
    func signUp(email: String, password: String) async throws -> SignupResult {
        SignupResult(session: nil, confirmationRequired: true)
    }
    func logIn(email: String, password: String) async throws {}
    func logIn(googleIDToken: String, nonce: String?) async throws {}
    func logIn(appleIDToken: String, nonce: String?) async throws {}
    func requestPasswordReset(email: String) async throws {}
    func resetPassword(email: String, code: String, newPassword: String) async throws {}
    func changePassword(current: String, new: String) async throws {}
    func signOut() async {}
    func deleteAccount() async throws {}

    func profile() async throws -> UserProfile { throw APIError.transport }
    func updateLevels(_ level: CEFRLevel) async throws {}
    func placementTest() async throws -> [PlacementQuestion] { [] }
    func submitPlacementTest(_ answers: [PlacementAnswer]) async throws -> PlacementResult { throw APIError.transport }
    func updateSettings(_ settings: SettingsUpdate) async throws {}
    func updateScope(_ scope: LearningScope) async throws {}
    func catalog() async throws -> [CatalogCollection] {
        TopicCatalog.collections.map { collection in
            CatalogCollection(
                id: collection.id,
                slug: collection.id,
                title: collection.name,
                description: collection.summary,
                topics: collection.topics.map { CatalogTopic(id: $0.id, slug: $0.id, title: $0.name, description: nil) }
            )
        }
    }

    func learnHome() async throws -> LearnHome {
        LearnHome(dueCount: 0, checkpointAvailable: 0, checkpointSessionsDone: 0, checkpointSessionsRequired: 7, learnedTotal: 0)
    }
    func checkpointChallenges() async throws -> [CheckpointChallenge] { [] }
    func journey(historyLimit: Int, before: Int?) async throws -> Journey { .preview }
    func words(limit: Int, offset: Int, query: String?) async throws -> [WordProgress] { [] }
    func wordStats() async throws -> WordStats { WordStats(learnedWords: 0, needPracticeWords: 0) }
    func wordDetail(id: String) async throws -> WordDetail { throw APIError.transport }

    func lookupCustomWord(_ query: CustomWordQuery) async throws -> CustomWordLookup { .invalid }
    func addCustomWord(_ addition: CustomWordAddition) async throws -> CustomWordAdded { throw APIError.transport }
    func customWords() async throws -> [CustomWord] { [] }
    func removeCustomWord(meaningID: String) async throws {}
    func overrideCustomWord(meaningID: String, edits: CustomWordEdits) async throws {}
    func clearCustomWordOverride(meaningID: String) async throws {}

    func planSession(_ request: PlanRequest) async throws -> SessionPlan {
        SessionPlan(sessionID: nil, mode: request.mode, steps: [])
    }
    func assessRecording(sessionID: String, taskID: String, audio: RecordedAudio) async throws -> RecordingAssessment {
        throw APIError.transport
    }
    func commitSession(sessionID: String, body: Data) async throws -> CommitResponse { throw APIError.transport }
    func commitStatus(sessionID: String) async throws -> CommitStatus { throw APIError.transport }

    func challengeMap() async throws -> ChallengeMap { .preview }
    func issueChallengeRun(chapterNo: Int, levelNo: Int) async throws -> ChallengeRunPlan { .sandbox() }
    func startChallengeRun(runID: String) async throws {}
    func commitChallengeRun(runID: String, body: Data) async throws -> ChallengeCommitResponse { throw APIError.transport }
    func challengeRunStatus(runID: String) async throws -> ChallengeRunStatus { throw APIError.transport }
    func quitChallengeRun(runID: String) async throws {}
}
