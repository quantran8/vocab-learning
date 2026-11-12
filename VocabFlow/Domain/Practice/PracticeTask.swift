import Foundation

enum SessionMode: String, Codable, Equatable {
    case daily
    case checkpointChallenge = "checkpoint_challenge"
    case randomPractice = "random_practice"
    case weakWordsPractice = "weak_words_practice"
}

/// Focuses `random_practice` on the chosen skills. The backend rejects it with any other mode.
enum PracticeSkill: String, Codable, Equatable, CaseIterable, Identifiable {
    case reading, writing, listening, speaking

    var id: String { rawValue }
}

struct PlanRequest: Encodable, Equatable {
    struct Capabilities: Encodable, Equatable {
        let audioPlayback: Bool
        let microphone: Bool
    }

    let mode: SessionMode
    let capabilities: Capabilities
    var challengeId: String?
    /// Nil is mixed practice; never empty (the backend rejects an empty list).
    var skills: [PracticeSkill]?
    /// Daily only: due reviews and no new words.
    var reviewOnly: Bool?
    /// Daily only: an optional "I know this" recall before each new word.
    var knownCheck: Bool?
    /// Random practice only: where the words come from. Nil is every learned word.
    var filter: PracticeFilter?
}

/// The source of a random practice. Encodes as the one key the backend expects.
enum PracticeFilter: Encodable, Equatable, Hashable {
    case collection(String)
    case topic(String)
    case customWords

    private enum CodingKeys: String, CodingKey {
        case collectionId, topicIds, customOnly
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .collection(let id): try container.encode(id, forKey: .collectionId)
        case .topic(let id): try container.encode([id], forKey: .topicIds)
        case .customWords: try container.encode(true, forKey: .customOnly)
        }
    }
}

/// Daily only: how many new words the plan gave and, when fewer than the goal, why.
struct NewWordsIssue: Decodable, Equatable {
    let requested: Int
    let issued: Int
    let withheldReason: NewWordReason?
}

struct SourceTopic: Decodable, Equatable {
    let id: String
    let name: String
}

/// One word the daily plan reviews, as the preview screen shows it.
struct PlanReviewWord: Decodable, Equatable {
    let wordId: String
    let meaningId: String
    let lemma: String
    let sourceTopic: SourceTopic?
}

/// The optional recall before a Learn card. Passed first try, the card and `skippableTaskIDs` are skipped.
struct KnownCheck: Equatable {
    let learnStepID: String
    let skippableTaskIDs: Set<String>
}

struct SessionPlan: Decodable, Equatable {
    /// Nil when there is nothing to learn or review; such a plan has no session to commit.
    let sessionID: String?
    let mode: SessionMode
    let steps: [PlanStep]
    /// Daily only; nil from an older backend.
    var newWords: NewWordsIssue? = nil
    var reviewWords: [PlanReviewWord]? = nil
    /// Review task id → its topic label.
    var sourceTopics: [String: SourceTopic] = [:]
    /// Known-check task id → the Learn step it can skip.
    var knownChecks: [String: KnownCheck] = [:]

    private enum CodingKeys: String, CodingKey {
        case sessionID = "sessionId", mode, steps, newWords, reviewWords
    }

    /// The extra fields a step may carry, read alongside `PlanStep` so the step enum stays as it is.
    private struct StepExtras: Decodable {
        struct TaskID: Decodable { let id: String }
        let id: String?
        let task: TaskID?
        let sourceTopic: SourceTopic?
        let knownCheckTaskId: String?
        let skippableTaskIds: [String]?
    }

    init(sessionID: String?, mode: SessionMode, steps: [PlanStep], newWords: NewWordsIssue? = nil,
         knownChecks: [String: KnownCheck] = [:]) {
        self.sessionID = sessionID
        self.mode = mode
        self.steps = steps
        self.newWords = newWords
        self.knownChecks = knownChecks
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        sessionID = try container.decodeIfPresent(String.self, forKey: .sessionID)
        mode = try container.decode(SessionMode.self, forKey: .mode)
        steps = try container.decode([PlanStep].self, forKey: .steps)
        newWords = try container.decodeIfPresent(NewWordsIssue.self, forKey: .newWords)
        reviewWords = try container.decodeIfPresent([PlanReviewWord].self, forKey: .reviewWords)
        let extras = try container.decode([StepExtras].self, forKey: .steps)
        for extra in extras {
            if let taskID = extra.task?.id, let topic = extra.sourceTopic { sourceTopics[taskID] = topic }
            if let learnID = extra.id, let checkID = extra.knownCheckTaskId {
                knownChecks[checkID] = KnownCheck(learnStepID: learnID, skippableTaskIDs: Set(extra.skippableTaskIds ?? []))
            }
        }
    }
}

struct AudioClip: Decodable, Equatable {
    let url: URL
    let locale: String
}

struct LearnCard: Decodable, Equatable {
    struct Example: Decodable, Equatable {
        let text: String
        let translation: String?
    }

    let word: String
    let meaning: String
    let definition: String?
    let ipa: String?
    let audio: AudioClip?
    let examples: [Example]?
    /// Optional: a plan started before the backend sent it has no value here.
    var partOfSpeech: String? = nil
    /// Open the word's other meanings; absent from plans made before the backend sent them.
    var wordId: String? = nil
    var meaningId: String? = nil
}

enum TaskPhase: Equatable {
    case dueReview, newPractice, knownCheck, checkpointChallenge, randomPractice, weakWordsPractice, other

    /// Display-only on the backend, so a new phase must not break the session.
    init(rawValue: String) {
        switch rawValue {
        case "due_review": self = .dueReview
        case "new_practice": self = .newPractice
        case "known_check": self = .knownCheck
        case "checkpoint_challenge": self = .checkpointChallenge
        case "random_practice": self = .randomPractice
        case "weak_words_practice": self = .weakWordsPractice
        default: self = .other
        }
    }
}

enum PlanStep: Decodable, Equatable {
    case learn(id: String, card: LearnCard)
    case practice(phase: TaskPhase, task: PracticeTask)

    var isDueReview: Bool {
        if case .practice(.dueReview, _) = self { return true }
        return false
    }

    private enum CodingKeys: String, CodingKey {
        case type, id, card, phase, task
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        switch type {
        case "learn":
            self = .learn(
                id: try container.decode(String.self, forKey: .id),
                card: try container.decode(LearnCard.self, forKey: .card)
            )
        case "practice":
            self = .practice(
                phase: TaskPhase(rawValue: try container.decode(String.self, forKey: .phase)),
                task: try container.decode(PracticeTask.self, forKey: .task)
            )
        default:
            throw DecodingError.dataCorruptedError(forKey: .type, in: container, debugDescription: "Unknown step \(type)")
        }
    }
}

/// The word a question points at, as the backend's string offsets: UTF-16 units, `end` excluded.
struct PromptHighlight: Decodable, Equatable {
    let start: Int
    let end: Int

    /// Nil when the offsets don't fit the text; the prompt then shows plain rather than failing the plan.
    func split(_ text: String) -> (before: String, word: String, after: String)? {
        let units = text.utf16
        guard start >= 0, start < end, end <= units.count else { return nil }
        let lower = units.index(units.startIndex, offsetBy: start)
        let upper = units.index(units.startIndex, offsetBy: end)
        return (String(text[..<lower]), String(text[lower..<upper]), String(text[upper...]))
    }
}

enum TaskPrompt: Decodable, Equatable {
    case text(String, highlight: PromptHighlight? = nil)
    case audio(AudioClip)

    private enum CodingKeys: String, CodingKey {
        case type, text, highlight, audio
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        switch type {
        case "text":
            self = .text(
                try container.decode(String.self, forKey: .text),
                highlight: try container.decodeIfPresent(PromptHighlight.self, forKey: .highlight)
            )
        case "audio": self = .audio(try container.decode(AudioClip.self, forKey: .audio))
        default:
            throw DecodingError.dataCorruptedError(forKey: .type, in: container, debugDescription: "Unknown prompt \(type)")
        }
    }

    var isAudio: Bool {
        if case .audio = self { return true }
        return false
    }
}

struct TaskOption: Decodable, Equatable, Identifiable {
    let id: Int
    let text: String
}

struct SentenceParts: Decodable, Equatable {
    let before: String
    let after: String
}

/// A cloze sentence split for layout. Text touching the blank, like a final period, stays attached to it.
struct ClozeLine: Equatable {
    let wordsBefore: [String]
    let attachedBefore: String
    let attachedAfter: String
    let wordsAfter: [String]

    init(_ parts: SentenceParts) {
        var before = parts.before.split(whereSeparator: \.isWhitespace).map(String.init)
        var after = parts.after.split(whereSeparator: \.isWhitespace).map(String.init)
        attachedBefore = parts.before.last?.isWhitespace == false ? before.removeLast() : ""
        attachedAfter = parts.after.first?.isWhitespace == false ? after.removeFirst() : ""
        wordsBefore = before
        wordsAfter = after
    }
}

struct PairKey: Decodable, Equatable {
    let leftId: Int
    let rightId: Int
}

enum TaskTemplate: String, Decodable, CaseIterable {
    case select, typing, match, surgery, recording
    case clozeSelect = "cloze_select"
    case flyReorder = "fly_reorder"

    var variants: Set<String> {
        switch self {
        case .select: ["gloss", "reverse_gloss", "meaning_clash", "phonetic_choice", "stress_choice"]
        case .clozeSelect: ["single_blank", "context_meaning"]
        case .typing: ["meaning_recall", "transcription"]
        case .flyReorder: ["spelling_recall", "transcription"]
        case .match: ["meaning_pairs", "word_pairs"]
        case .surgery: ["fix_spelling"]
        case .recording: ["scripted_pronunciation"]
        }
    }
}

/// What the learner interacts with, including the answer key for instant feedback.
/// The backend re-scores everything at commit, so the key must never be logged or shown early.
enum TaskBody: Equatable {
    case choice(options: [TaskOption], sentence: SentenceParts?, correctOptionID: Int)
    case typing(accepted: [String])
    case reorder(tiles: [TaskOption], accepted: [String])
    case match(left: [TaskOption], right: [TaskOption], correct: [PairKey])
    case surgery(word: String, wrongGraphemeIndex: Int, replacement: String)
    /// The text to read. Empty for sessions issued before the backend sent it.
    case recording(accepted: [String])
}

/// An unknown template or variant fails the whole plan: commit needs a result for every task,
/// so one that can't be rendered can't be skipped.
struct PracticeTask: Decodable, Equatable, Identifiable {
    let id: String
    let template: TaskTemplate
    let variant: String
    /// Nil only for a cloze with no clue: its sentence is the stimulus.
    let prompt: TaskPrompt?
    let question: String?
    let body: TaskBody
    /// Tries after a wrong answer, so 1 + this in total. Nil means unlimited: sessions issued before the limit.
    let maxRetries: Int?

    private enum CodingKeys: String, CodingKey {
        case id, template, variant, prompt, question, options, sentenceParts, tiles, pairs, word, evaluation, maxRetries
    }

    private struct Pairs: Decodable {
        let left: [TaskOption]
        let right: [TaskOption]
    }

    private struct Evaluation: Decodable {
        let correctOptionId: Int?
        let acceptedResponses: [String]?
        let correctPairs: [PairKey]?
        let wrongGraphemeIndex: Int?
        let replacement: String?
    }

    init(id: String, template: TaskTemplate, variant: String, prompt: TaskPrompt?, question: String?, body: TaskBody, maxRetries: Int? = nil) {
        self.id = id
        self.template = template
        self.variant = variant
        self.prompt = prompt
        self.question = question
        self.body = body
        self.maxRetries = maxRetries
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        template = try container.decode(TaskTemplate.self, forKey: .template)
        variant = try container.decode(String.self, forKey: .variant)
        guard template.variants.contains(variant) else {
            throw DecodingError.dataCorruptedError(forKey: .variant, in: container, debugDescription: "Unknown variant \(variant)")
        }
        prompt = try template == .clozeSelect
            ? container.decodeIfPresent(TaskPrompt.self, forKey: .prompt)
            : container.decode(TaskPrompt.self, forKey: .prompt)
        question = try container.decodeIfPresent(String.self, forKey: .question)
        body = try Self.decodeBody(template, container)
        maxRetries = try container.decodeIfPresent(Int.self, forKey: .maxRetries)
    }

    private static func decodeBody(_ template: TaskTemplate, _ container: KeyedDecodingContainer<CodingKeys>) throws -> TaskBody {
        guard template != .recording else {
            let evaluation = try container.decodeIfPresent(Evaluation.self, forKey: .evaluation)
            return .recording(accepted: evaluation?.acceptedResponses ?? [])
        }
        let evaluation = try container.decode(Evaluation.self, forKey: .evaluation)

        func required<Value>(_ value: Value?) throws -> Value {
            guard let value else {
                throw DecodingError.dataCorruptedError(forKey: .evaluation, in: container, debugDescription: "Missing answer key")
            }
            return value
        }

        switch template {
        case .select, .clozeSelect:
            return .choice(
                options: try container.decode([TaskOption].self, forKey: .options),
                sentence: template == .clozeSelect ? try container.decode(SentenceParts.self, forKey: .sentenceParts) : nil,
                correctOptionID: try required(evaluation.correctOptionId)
            )
        case .typing:
            return .typing(accepted: try required(evaluation.acceptedResponses))
        case .flyReorder:
            return .reorder(
                tiles: try container.decode([TaskOption].self, forKey: .tiles),
                accepted: try required(evaluation.acceptedResponses)
            )
        case .match:
            let pairs = try container.decode(Pairs.self, forKey: .pairs)
            return .match(left: pairs.left, right: pairs.right, correct: try required(evaluation.correctPairs))
        case .surgery:
            return .surgery(
                word: try container.decode(String.self, forKey: .word),
                wrongGraphemeIndex: try required(evaluation.wrongGraphemeIndex),
                replacement: try required(evaluation.replacement)
            )
        case .recording:
            return .recording(accepted: evaluation.acceptedResponses ?? [])
        }
    }
}

// MARK: - Recording and commit

struct RecordedAudio: Equatable {
    /// Passed through to Azure Speech by the backend.
    static let wavContentType = "audio/wav; codecs=audio/pcm; samplerate=16000"

    let data: Data
    var contentType = RecordedAudio.wavContentType
}

struct RecordingAssessment: Decodable, Equatable {
    let assessmentReceiptId: String
    let validity: String
    let passed: Bool?
    let accuracyScore: Double?
    /// On-device scoring only: the normalized transcript that was scored.
    var heard: String? = nil

    /// False for silence or noise: not a fail, the learner should just read again.
    var isValid: Bool { validity == "valid" }
}

struct CommitSummary: Decodable, Equatable {
    let newWordGoalSlots: Int
    let reviewedMeanings: Int
    let practiceTasks: Int
    /// Only for a checkpoint challenge (the Journey's review).
    var checkpoint: ReviewResult? = nil
    /// Words passed with "I know this"; nil from an older backend.
    var knownMeanings: Int? = nil
}

/// Set only by the commit that used up a topic, the scope or the whole collection; a retry repeats it.
struct ScopeEvents: Decodable, Equatable {
    let completedTopicIds: [String]
    let scopeExhausted: Bool
    let collectionCompleted: Bool

    var isEmpty: Bool { completedTopicIds.isEmpty && !scopeExhausted && !collectionCompleted }
}

struct CommitResponse: Decodable, Equatable {
    let sessionId: String
    let summary: CommitSummary
    var scopeEvents: ScopeEvents? = nil
    /// LP and lifetime Tier from this commit; nil from a backend without them. A retry repeats them.
    var lp: CommitLP? = nil
    var tier: CommitTier? = nil
    var ranking: CommitRanking? = nil
}

struct CommitStatus: Decodable, Equatable {
    let status: String
    let response: CommitResponse?
}
