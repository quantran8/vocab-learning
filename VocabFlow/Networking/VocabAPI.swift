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

    var hasFinishedOnboarding: Bool { proficiencyLevel != nil && scope != nil }
}

/// `PUT /me/settings` is strict: nil fields are omitted from the body.
struct SettingsUpdate: Encodable, Equatable {
    var explanationLocale: String?
    var uiLocale: String?
    var timeZone: String?
    var dailyNewWordGoal: Int?
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

struct CatalogTopic: Decodable, Equatable {
    let id: String
    let slug: String
    let title: String
    let description: String?
}

struct CatalogCollection: Decodable, Equatable {
    let id: String
    let slug: String
    let title: String
    let description: String?
    let topics: [CatalogTopic]
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

    var checkpointProgress: Double {
        guard checkpointSessionsRequired > 0 else { return 0 }
        return min(Double(checkpointSessionsDone) / Double(checkpointSessionsRequired), 1)
    }
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
    func checkpointChallenges() async throws -> [CheckpointChallenge]
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

    func checkpointChallenges() async throws -> [CheckpointChallenge] {
        let response: CheckpointResponse = try await client.send(get("me/checkpoint-challenges"))
        return response.challenges
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

    private struct CheckpointResponse: Decodable {
        let challenges: [CheckpointChallenge]
    }

    private struct WordsResponse: Decodable {
        let words: [WordProgress]
    }

    private struct CustomWordsResponse: Decodable {
        let words: [CustomWord]
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
}
