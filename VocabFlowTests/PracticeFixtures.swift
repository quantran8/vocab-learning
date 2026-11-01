import Foundation
@testable import VocabFlow

enum PracticeFixtures {
    static func choice(id: String = "t-choice", maxRetries: Int? = nil) -> PracticeTask {
        PracticeTask(
            id: id, template: .select, variant: "gloss", prompt: .text("clarify"), question: "?",
            body: .choice(options: [TaskOption(id: 7, text: "a"), TaskOption(id: 3, text: "b")], sentence: nil, correctOptionID: 3),
            maxRetries: maxRetries
        )
    }

    static func typing(id: String = "t-typing", prompt: TaskPrompt = .text("làm rõ")) -> PracticeTask {
        PracticeTask(id: id, template: .typing, variant: "meaning_recall", prompt: prompt, question: nil, body: .typing(accepted: ["clarify"]))
    }

    static func reorder(id: String = "t-reorder") -> PracticeTask {
        PracticeTask(
            id: id, template: .flyReorder, variant: "spelling_recall", prompt: .text("đi"), question: nil,
            body: .reorder(tiles: [TaskOption(id: 1, text: "o"), TaskOption(id: 2, text: "g")], accepted: ["go"])
        )
    }

    static func match(maxRetries: Int? = nil) -> PracticeTask {
        PracticeTask(
            id: "t-match", template: .match, variant: "meaning_pairs", prompt: .text("Match"), question: nil,
            body: .match(
                left: [TaskOption(id: 1, text: "a"), TaskOption(id: 2, text: "b")],
                right: [TaskOption(id: 5, text: "x"), TaskOption(id: 6, text: "y")],
                correct: [PairKey(leftId: 1, rightId: 5), PairKey(leftId: 2, rightId: 6)]
            ),
            maxRetries: maxRetries
        )
    }

    static func surgery() -> PracticeTask {
        PracticeTask(
            id: "t-surgery", template: .surgery, variant: "fix_spelling", prompt: .text("Fix"), question: nil,
            body: .surgery(word: "clarrify", wrongGraphemeIndex: 4, replacement: "")
        )
    }

    static func recording(prompt: TaskPrompt = .text("clarify"), maxRetries: Int? = nil) -> PracticeTask {
        PracticeTask(id: "t-recording", template: .recording, variant: "scripted_pronunciation", prompt: prompt, question: nil, body: .recording, maxRetries: maxRetries)
    }

    static let clip = AudioClip(url: URL(string: "https://example.com/a.mp3")!, locale: "en-US")

    static let card = LearnCard(word: "clarify", meaning: "làm rõ", definition: nil, ipa: nil, audio: nil, examples: nil)

    static func word(_ lemma: String, nextReviewAt: Date?) -> WordProgress {
        let skill = SkillState(status: .notVerified, needsPractice: false)
        let meaning = WordMeaning(
            meaning: WordMeaning.Sense(partOfSpeech: "verb", text: "nghĩa của \(lemma)", ipa: nil),
            learnedAt: nil,
            nextReviewAt: nextReviewAt,
            skills: MeaningSkills(reading: skill, writing: skill, listening: nil, speaking: nil),
            needsPractice: false
        )
        return WordProgress(wordId: lemma, lemma: lemma, meanings: [meaning], needsPractice: false, fullyVerified: false)
    }

    static func json(_ value: some Encodable) throws -> Any {
        try JSONSerialization.jsonObject(with: JSONEncoder().encode(value))
    }
}

/// Scripted backend; each closure defaults to the offline answer.
final class StubVocabAPI: VocabAPI, @unchecked Sendable {
    var plan: Result<SessionPlan, APIError> = .failure(.transport)
    var commitResults: [Result<CommitResponse, APIError>] = []
    var assessResult: Result<RecordingAssessment, APIError> = .failure(.transport)
    var status: CommitStatus?
    private(set) var commitBodies: [Data] = []
    private(set) var planRequests: [PlanRequest] = []
    var library: [WordProgress] = []
    var wordsError: APIError?
    var lookupResults: [Result<CustomWordLookup, APIError>] = []
    var addResults: [Result<CustomWordAdded, APIError>] = []
    var customWordList: [CustomWord] = []
    var removeError: APIError?
    var onLookup: (() async -> Void)?
    private(set) var lookups: [CustomWordQuery] = []
    private(set) var removed: [String] = []

    func hasStoredSession() async -> Bool { true }
    func signUp(email: String, password: String) async throws -> SignupResult { SignupResult(session: nil, confirmationRequired: true) }
    func logIn(email: String, password: String) async throws {}
    func logIn(googleIDToken: String, nonce: String?) async throws {}
    func signOut() async {}
    func profile() async throws -> UserProfile { throw APIError.transport }
    func updateLevels(_ level: CEFRLevel) async throws {}
    func updateSettings(_ settings: SettingsUpdate) async throws {}
    func updateScope(_ scope: LearningScope) async throws {}
    func catalog() async throws -> [CatalogCollection] { [] }
    func learnHome() async throws -> LearnHome { LearnHome(dueCount: 0, checkpointAvailable: 0, checkpointSessionsDone: 0, checkpointSessionsRequired: 7, learnedTotal: 0) }
    func checkpointChallenges() async throws -> [CheckpointChallenge] { [] }
    func words(limit: Int, offset: Int) async throws -> [WordProgress] {
        if let wordsError { throw wordsError }
        return Array(library.dropFirst(offset).prefix(limit))
    }

    func lookupCustomWord(_ query: CustomWordQuery) async throws -> CustomWordLookup {
        lookups.append(query)
        await onLookup?()
        return try lookupResults.removeFirst().get()
    }

    func addCustomWord(_ addition: CustomWordAddition) async throws -> CustomWordAdded {
        try addResults.removeFirst().get()
    }

    func customWords() async throws -> [CustomWord] { customWordList }

    func removeCustomWord(meaningID: String) async throws {
        if let removeError { throw removeError }
        removed.append(meaningID)
    }

    func overrideCustomWord(meaningID: String, edits: CustomWordEdits) async throws {}
    func clearCustomWordOverride(meaningID: String) async throws {}

    func planSession(_ request: PlanRequest) async throws -> SessionPlan {
        planRequests.append(request)
        return try plan.get()
    }

    func assessRecording(sessionID: String, taskID: String, audio: RecordedAudio) async throws -> RecordingAssessment {
        try assessResult.get()
    }

    func commitSession(sessionID: String, body: Data) async throws -> CommitResponse {
        commitBodies.append(body)
        return try commitResults.removeFirst().get()
    }

    func commitStatus(sessionID: String) async throws -> CommitStatus {
        guard let status else { throw APIError.transport }
        return status
    }
}

final class StubRecorder: VoiceRecording {
    var canRecord = true
    var hasAccess = true
    var onLimitReached: (@MainActor () -> Void)?
    func requestAccess() async -> Bool { hasAccess }
    func start() throws {}
    func stop() -> RecordedAudio? { RecordedAudio(data: Data([1])) }
    func cancel() {}
}
