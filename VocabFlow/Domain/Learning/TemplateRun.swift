import Foundation

struct TemplateAttempt: Equatable {
    let templateID: TemplateKind
    let exerciseID: String
    let submission: String
    let isCorrect: Bool
    let hintsUsed: Int
}

enum TemplatePhase: Equatable {
    case ready
    case incorrect
    case correct
    case revealed
    case selfChecked

    var isFinished: Bool {
        switch self {
        case .correct, .revealed, .selfChecked: true
        case .ready, .incorrect: false
        }
    }
}

enum TemplateFeedback: Equatable {
    case correct
    case wrongChoice(choiceID: String)
    case wrongTyped(String)
    case pairMatched(wordID: String)
    case pairMismatched(wordID: String, glossWordID: String)
    case letterLocated(index: Int)
    case wrongLetter(index: Int)
    case wrongRepair(String)
    case wrongStress(index: Int)
    case revealed
    case selfChecked
}

enum TemplateEvent: Equatable {
    case correct, incorrect, progressed, hintOpened, revealed, selfChecked, audioPlayed
}

/// One ephemeral Practice Lab exercise. Pure value type; never touches the scored session.
struct TemplateRun: Equatable {
    let kind: TemplateKind
    let exercise: TemplateExercise
    let word: VocabularyItem
    let pairWords: [VocabularyItem]

    private(set) var phase: TemplatePhase = .ready
    private(set) var feedback: TemplateFeedback?
    private(set) var attempts: [TemplateAttempt] = []
    private(set) var hintsUsed = 0
    private(set) var audioPlayCount = 0
    private(set) var usesAudioFallback = false
    private(set) var matchedWordIDs: Set<String> = []
    private(set) var locatedLetterIndex: Int?
    /// Typed templates distinguish first-try, hinted, retried and revealed — reusing the core vocabulary.
    private(set) var typedOutcome: RecallOutcome?

    init(kind: TemplateKind, exercise: TemplateExercise, word: VocabularyItem, pairWords: [VocabularyItem] = []) {
        self.kind = kind
        self.exercise = exercise
        self.word = word
        self.pairWords = pairWords
    }

    var hints: [String] { TemplateEvaluator.hints(for: exercise, word: word) }
    var revealedHints: [String] { Array(hints.prefix(hintsUsed)) }
    var canSelfCheck: Bool { !phase.isFinished && (audioPlayCount > 0 || usesAudioFallback) }

    // MARK: Choice-based: select, audioSelect, stack, snap

    mutating func submitChoice(_ choiceID: String) -> [TemplateEvent] {
        guard !phase.isFinished, exercise.choice(id: choiceID) != nil,
              feedback != .wrongChoice(choiceID: choiceID)
        else { return [] }
        let isCorrect = TemplateEvaluator.isCorrect(choiceID: choiceID, for: exercise)
        record(choiceID, isCorrect: isCorrect)
        return finish(isCorrect, wrong: .wrongChoice(choiceID: choiceID))
    }

    // MARK: Typed: fill, typing, trace

    mutating func submitText(_ text: String) -> [TemplateEvent] {
        let submission = AnswerEvaluator.normalize(text)
        guard !phase.isFinished, !submission.isEmpty, feedback != .wrongTyped(submission) else { return [] }
        let previousAttempts = attempts.count
        let isCorrect = TemplateEvaluator.isCorrect(typed: text, for: exercise, word: word)
        record(submission, isCorrect: isCorrect)
        if isCorrect {
            typedOutcome = hintsUsed > 0 ? .hintedRecall : (previousAttempts == 0 ? .unaidedRecall : .recalledAfterRetry)
        }
        return finish(isCorrect, wrong: .wrongTyped(submission))
    }

    mutating func requestHint() -> [TemplateEvent] {
        guard !phase.isFinished, hintsUsed < hints.count else { return [] }
        hintsUsed += 1
        return [.hintOpened]
    }

    mutating func reveal() -> [TemplateEvent] {
        guard !phase.isFinished else { return [] }
        phase = .revealed
        feedback = .revealed
        typedOutcome = .notRecalled
        return [.revealed]
    }

    // MARK: Matching Pairs

    mutating func selectPair(wordID: String, glossWordID: String) -> [TemplateEvent] {
        let ids = Set(pairWords.map(\.id))
        guard !phase.isFinished, ids.contains(wordID), ids.contains(glossWordID),
              !matchedWordIDs.contains(wordID), !matchedWordIDs.contains(glossWordID)
        else { return [] }
        let isMatch = TemplateEvaluator.isMatch(wordID: wordID, glossWordID: glossWordID)
        record("\(wordID)=\(glossWordID)", isCorrect: isMatch)
        guard isMatch else {
            // Matching resets its own picks after a mismatch, so it stays playable (no "Try again").
            phase = .ready
            feedback = .pairMismatched(wordID: wordID, glossWordID: glossWordID)
            return [.incorrect]
        }
        matchedWordIDs.insert(wordID)
        if matchedWordIDs.count == ids.count {
            phase = .correct
            feedback = .correct
            return [.correct]
        }
        phase = .ready
        feedback = .pairMatched(wordID: wordID)
        return [.progressed]
    }

    // MARK: Letter Surgery — locate, then repair

    mutating func locateLetter(at index: Int) -> [TemplateEvent] {
        guard !phase.isFinished, locatedLetterIndex == nil,
              exercise.misspellingLetters.indices.contains(index),
              feedback != .wrongLetter(index: index)
        else { return [] }
        let isCorrect = TemplateEvaluator.isWrongCharacter(index: index, in: exercise)
        record("index:\(index)", isCorrect: isCorrect)
        guard isCorrect else {
            phase = .incorrect
            feedback = .wrongLetter(index: index)
            return [.incorrect]
        }
        locatedLetterIndex = index
        phase = .ready
        feedback = .letterLocated(index: index)
        return [.progressed]
    }

    mutating func repairLetter(with replacement: String) -> [TemplateEvent] {
        guard !phase.isFinished, locatedLetterIndex != nil,
              exercise.replacementChoices?.contains(replacement) == true,
              feedback != .wrongRepair(replacement)
        else { return [] }
        let isCorrect = TemplateEvaluator.isCorrectRepair(replacement, for: exercise, word: word)
        record("letter:\(replacement)", isCorrect: isCorrect)
        return finish(isCorrect, wrong: .wrongRepair(replacement))
    }

    // MARK: Sound Split

    mutating func submitStress(_ syllableIndex: Int) -> [TemplateEvent] {
        guard !phase.isFinished, word.syllables.indices.contains(syllableIndex),
              feedback != .wrongStress(index: syllableIndex)
        else { return [] }
        let isCorrect = TemplateEvaluator.isStressed(syllableIndex: syllableIndex, in: word)
        record("syllable:\(syllableIndex)", isCorrect: isCorrect)
        return finish(isCorrect, wrong: .wrongStress(index: syllableIndex))
    }

    // MARK: Audio & Echo Back

    mutating func recordAudioPlayed() -> [TemplateEvent] {
        audioPlayCount += 1
        return [.audioPlayed]
    }

    mutating func useAudioFallback() {
        usesAudioFallback = true
    }

    /// Echo Back is a learner self-report. It is never graded or credited as pronunciation.
    mutating func selfCheck() -> [TemplateEvent] {
        guard canSelfCheck else { return [] }
        phase = .selfChecked
        feedback = .selfChecked
        return [.selfChecked]
    }

    /// "Try again" after a wrong answer: clears feedback so the step can be answered fresh.
    /// Attempts, hints, replays and a located Letter Surgery index stay recorded.
    mutating func dismissFeedback() -> [TemplateEvent] {
        guard phase == .incorrect else { return [] }
        phase = .ready
        feedback = nil
        return []
    }

    // MARK: Helpers

    private mutating func record(_ submission: String, isCorrect: Bool) {
        attempts.append(TemplateAttempt(templateID: kind, exerciseID: exercise.id, submission: submission, isCorrect: isCorrect, hintsUsed: hintsUsed))
    }

    private mutating func finish(_ isCorrect: Bool, wrong: TemplateFeedback) -> [TemplateEvent] {
        phase = isCorrect ? .correct : .incorrect
        feedback = isCorrect ? .correct : wrong
        return [isCorrect ? .correct : .incorrect]
    }
}
