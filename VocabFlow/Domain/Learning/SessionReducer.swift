import Foundation

enum SessionPhase: Equatable, Hashable {
    case home
    case learn(index: Int)
    case build(index: Int)
    case recall(index: Int)
    case results
}

enum SessionFeedback: Equatable {
    case buildCorrect(tileID: String)
    case buildIncorrect(tileID: String)
    case recallCorrect(RecallOutcome)
    case recallIncorrect(submission: String, attemptsRemaining: Int)
    case recallRevealed
}

struct SessionState: Equatable {
    var phase: SessionPhase = .home
    var attempts: [Attempt] = []
    var hintsByWordID: [String: Int] = [:]
    var recallOutcomes: [String: RecallOutcome] = [:]
    var feedback: SessionFeedback?
}

enum SessionAction: Equatable {
    case start
    case learnedNext
    case buildSubmitted(tileID: String)
    case recallSubmitted(String)
    case hintRequested
    case answerRevealed
    case advance
    case restart
}

enum SessionEvent: Equatable {
    case started
    case correct
    case incorrect
    case hintOpened
    case answerRevealed
    case advanced
    case finished
    case restarted
}

struct SessionTransition: Equatable {
    let state: SessionState
    let events: [SessionEvent]

    static func unchanged(_ state: SessionState) -> SessionTransition {
        SessionTransition(state: state, events: [])
    }
}

enum SessionReducer {
    static let maxRecallAttempts = 3

    static func reduce(state: SessionState, action: SessionAction, content: DemoContent) -> SessionTransition {
        var next = state

        switch (action, state.phase) {
        case (.start, .home):
            next.phase = content.words.isEmpty ? .results : .learn(index: 0)
            return SessionTransition(state: next, events: [.started])

        case (.learnedNext, .learn(let index)):
            next.phase = index + 1 < content.words.count ? .learn(index: index + 1) : firstBuildPhase(content)
            next.feedback = nil
            return SessionTransition(state: next, events: [.advanced])

        case (.buildSubmitted(let tileID), .build(let index)):
            return submitBuild(tileID: tileID, index: index, state: state, content: content)

        case (.recallSubmitted(let text), .recall(let index)):
            return submitRecall(text: text, index: index, state: state, content: content)

        case (.hintRequested, .recall(let index)):
            guard let word = recallWord(index, content), state.recallOutcomes[word.id] == nil else { return .unchanged(state) }
            let used = state.hintsByWordID[word.id, default: 0]
            guard used < HintSequence.maxHints else { return .unchanged(state) }
            next.hintsByWordID[word.id] = used + 1
            return SessionTransition(state: next, events: [.hintOpened])

        case (.answerRevealed, .recall(let index)):
            guard let word = recallWord(index, content), state.recallOutcomes[word.id] == nil else { return .unchanged(state) }
            next.recallOutcomes[word.id] = .notRecalled
            next.feedback = .recallRevealed
            return SessionTransition(state: next, events: [.answerRevealed])

        case (.advance, .build(let index)):
            guard isBuildCompleted(index: index, state: state, content: content) else { return .unchanged(state) }
            next.phase = index + 1 < content.buildChallenges.count ? .build(index: index + 1) : firstRecallPhase(content)
            next.feedback = nil
            return SessionTransition(state: next, events: [.advanced])

        case (.advance, .recall(let index)):
            guard let word = recallWord(index, content), state.recallOutcomes[word.id] != nil else { return .unchanged(state) }
            let isLast = index + 1 >= content.recallPrompts.count
            next.phase = isLast ? .results : .recall(index: index + 1)
            next.feedback = nil
            return SessionTransition(state: next, events: [isLast ? .finished : .advanced])

        case (.restart, _):
            return SessionTransition(state: SessionState(), events: [.restarted])

        default:
            return .unchanged(state)
        }
    }

    static func isBuildCompleted(index: Int, state: SessionState, content: DemoContent) -> Bool {
        guard content.buildChallenges.indices.contains(index) else { return false }
        let challengeID = content.buildChallenges[index].id
        return state.attempts.contains { $0.stage == .build && $0.challengeID == challengeID && $0.isCorrect }
    }

    static func result(state: SessionState, content: DemoContent) -> SessionResult {
        SessionResult(words: content.words.map { word in
            let attempts = state.attempts.filter { $0.wordID == word.id }
            return WordResult(
                wordID: word.id,
                term: word.term,
                recognized: attempts.contains { $0.stage == .build && $0.isCorrect },
                buildAttemptCount: attempts.filter { $0.stage == .build }.count,
                recallAttemptCount: attempts.filter { $0.stage == .recall }.count,
                hintCount: state.hintsByWordID[word.id, default: 0],
                recallOutcome: state.recallOutcomes[word.id]
            )
        })
    }

    private static func submitBuild(tileID: String, index: Int, state: SessionState, content: DemoContent) -> SessionTransition {
        guard content.buildChallenges.indices.contains(index) else { return .unchanged(state) }
        let challenge = content.buildChallenges[index]
        guard challenge.option(id: tileID) != nil,
              !isBuildCompleted(index: index, state: state, content: content),
              state.feedback != .buildIncorrect(tileID: tileID)
        else { return .unchanged(state) }

        let isCorrect = AnswerEvaluator.isCorrect(tileID: tileID, for: challenge)
        var next = state
        next.attempts.append(Attempt(stage: .build, wordID: challenge.wordID, challengeID: challenge.id, submission: tileID, isCorrect: isCorrect, hintsUsed: 0))
        next.feedback = isCorrect ? .buildCorrect(tileID: tileID) : .buildIncorrect(tileID: tileID)
        return SessionTransition(state: next, events: [isCorrect ? .correct : .incorrect])
    }

    private static func submitRecall(text: String, index: Int, state: SessionState, content: DemoContent) -> SessionTransition {
        guard content.recallPrompts.indices.contains(index), let word = recallWord(index, content) else { return .unchanged(state) }
        let prompt = content.recallPrompts[index]
        let submission = AnswerEvaluator.normalize(text)
        guard !submission.isEmpty, state.recallOutcomes[word.id] == nil else { return .unchanged(state) }
        if case .recallIncorrect(let previous, _) = state.feedback, previous == submission {
            return .unchanged(state)
        }

        let hints = state.hintsByWordID[word.id, default: 0]
        let previousAttempts = state.attempts.filter { $0.stage == .recall && $0.wordID == word.id }.count
        let isCorrect = AnswerEvaluator.isCorrect(typed: text, for: word)

        var next = state
        next.attempts.append(Attempt(stage: .recall, wordID: word.id, challengeID: prompt.id, submission: submission, isCorrect: isCorrect, hintsUsed: hints))

        if isCorrect {
            let outcome: RecallOutcome
            if hints > 0 {
                outcome = .hintedRecall
            } else if previousAttempts == 0 {
                outcome = .unaidedRecall
            } else {
                outcome = .recalledAfterRetry
            }
            next.recallOutcomes[word.id] = outcome
            next.feedback = .recallCorrect(outcome)
            return SessionTransition(state: next, events: [.correct])
        }

        let remaining = maxRecallAttempts - (previousAttempts + 1)
        if remaining <= 0 {
            next.recallOutcomes[word.id] = .notRecalled
            next.feedback = .recallRevealed
        } else {
            next.feedback = .recallIncorrect(submission: submission, attemptsRemaining: remaining)
        }
        return SessionTransition(state: next, events: [.incorrect])
    }

    private static func recallWord(_ index: Int, _ content: DemoContent) -> VocabularyItem? {
        guard content.recallPrompts.indices.contains(index) else { return nil }
        return content.word(id: content.recallPrompts[index].wordID)
    }

    private static func firstBuildPhase(_ content: DemoContent) -> SessionPhase {
        content.buildChallenges.isEmpty ? firstRecallPhase(content) : .build(index: 0)
    }

    private static func firstRecallPhase(_ content: DemoContent) -> SessionPhase {
        content.recallPrompts.isEmpty ? .results : .recall(index: 0)
    }
}
