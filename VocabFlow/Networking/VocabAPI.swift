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

struct SkillState: Decodable, Equatable {
    let status: SkillStatus
    let needsPractice: Bool
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
    }

    let meaning: Sense
    let learnedAt: Date?
    let nextReviewAt: Date?
    let skills: MeaningSkills
    let needsPractice: Bool
}

struct WordProgress: Decodable, Equatable, Identifiable {
    let wordId: String
    let lemma: String
    let meanings: [WordMeaning]
    let needsPractice: Bool
    let fullyVerified: Bool

    var id: String { wordId }
    var learnedAt: Date? { meanings.compactMap(\.learnedAt).max() }
    var meaningText: String { meanings.map(\.meaning.text).joined(separator: "; ") }

    func isDue(on date: Date) -> Bool {
        meanings.contains { $0.nextReviewAt.map { $0 <= date } ?? false }
    }

    /// Case- and diacritic-insensitive match on the English word or its meanings.
    func matches(_ query: String) -> Bool {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !needle.isEmpty else { return true }
        let options: String.CompareOptions = [.caseInsensitive, .diacriticInsensitive]
        return lemma.range(of: needle, options: options) != nil || meaningText.range(of: needle, options: options) != nil
    }
}

// MARK: - API surface

/// Everything the app asks of the backend. Stores depend on this, so tests and previews can stub it.
protocol VocabAPI: Sendable {
    func hasStoredSession() async -> Bool
    func signUp(email: String, password: String) async throws -> SignupResult
    func logIn(email: String, password: String) async throws
    func logIn(googleIDToken: String, nonce: String?) async throws
    func signOut() async

    func profile() async throws -> UserProfile
    func updateLevels(_ level: CEFRLevel) async throws
    func updateSettings(_ settings: SettingsUpdate) async throws
    func updateScope(_ scope: LearningScope) async throws
    func catalog() async throws -> [CatalogCollection]

    func learnHome() async throws -> LearnHome
    func checkpointChallenges() async throws -> [CheckpointChallenge]
    func words(limit: Int, offset: Int) async throws -> [WordProgress]

    func planSession(_ request: PlanRequest) async throws -> SessionPlan
    func assessRecording(sessionID: String, taskID: String, audio: RecordedAudio) async throws -> RecordingAssessment
    /// `body` is sent as is: a retried commit must repeat the first attempt's bytes.
    func commitSession(sessionID: String, body: Data) async throws -> CommitResponse
    func commitStatus(sessionID: String) async throws -> CommitStatus
}

struct LiveVocabAPI: VocabAPI {
    let client: APIClient
    /// The commit is idempotent, so it may retry harder than other requests.
    private static let commitRetries = 3
    private static let readRetries = 2

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
            try post("auth/google", GoogleCredentials(idToken: googleIDToken, nonce: nonce), requiresAuth: false)
        )
        await client.store(session)
    }

    func signOut() async {
        await client.signOut()
    }

    func profile() async throws -> UserProfile {
        try await client.send(get("me"))
    }

    func updateLevels(_ level: CEFRLevel) async throws {
        var request = try post("me/levels", Levels(proficiencyLevel: level))
        request.method = .put
        _ = try await client.sendRaw(request)
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

    func words(limit: Int, offset: Int) async throws -> [WordProgress] {
        var request = get("me/words")
        request.query = [
            URLQueryItem(name: "limit", value: String(limit)),
            URLQueryItem(name: "offset", value: String(offset)),
        ]
        let response: WordsResponse = try await client.send(request)
        return response.words
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

    private struct GoogleCredentials: Encodable {
        let idToken: String
        let nonce: String?
    }

    private struct Levels: Encodable {
        let proficiencyLevel: CEFRLevel
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
}

/// Answers every call with nothing, for previews and tests that don't exercise the backend.
struct OfflineVocabAPI: VocabAPI {
    func hasStoredSession() async -> Bool { true }
    func signUp(email: String, password: String) async throws -> SignupResult {
        SignupResult(session: nil, confirmationRequired: true)
    }
    func logIn(email: String, password: String) async throws {}
    func logIn(googleIDToken: String, nonce: String?) async throws {}
    func signOut() async {}

    func profile() async throws -> UserProfile { throw APIError.transport }
    func updateLevels(_ level: CEFRLevel) async throws {}
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
    func words(limit: Int, offset: Int) async throws -> [WordProgress] { [] }

    func planSession(_ request: PlanRequest) async throws -> SessionPlan {
        SessionPlan(sessionID: nil, mode: request.mode, steps: [])
    }
    func assessRecording(sessionID: String, taskID: String, audio: RecordedAudio) async throws -> RecordingAssessment {
        throw APIError.transport
    }
    func commitSession(sessionID: String, body: Data) async throws -> CommitResponse { throw APIError.transport }
    func commitStatus(sessionID: String) async throws -> CommitStatus { throw APIError.transport }
}
