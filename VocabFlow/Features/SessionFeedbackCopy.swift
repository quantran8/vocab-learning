import Foundation

/// User-facing explanation for the current core-session feedback, shown in the pinned panel.
@MainActor
enum SessionFeedbackCopy {
    static func make(phase: SessionPhase, store: SessionStore) -> FeedbackCopy? {
        switch phase {
        case .build(let index):
            guard let challenge = store.buildChallenge(at: index) else { return nil }
            return build(store.state.feedback, challenge: challenge)
        case .recall(let index):
            guard let prompt = store.recallPrompt(at: index), let word = store.word(id: prompt.wordID) else { return nil }
            return recall(store.state.feedback, word: word)
        case .home, .learn, .results:
            return nil
        }
    }

    private static func build(_ feedback: SessionFeedback?, challenge: BuildChallenge) -> FeedbackCopy? {
        switch feedback {
        case .buildCorrect(let tileID):
            let text = challenge.option(id: tileID)?.text ?? ""
            return FeedbackCopy(
                kind: .success,
                title: String(localized: "Nicely done!"),
                message: String(localized: "“\(challenge.filledPrompt(with: text))” — “\(text)” fits this context.")
            )
        case .buildIncorrect(let tileID):
            let text = challenge.option(id: tileID)?.text ?? ""
            return FeedbackCopy(
                kind: .error,
                title: String(localized: "Not quite — try another word"),
                message: challenge.explanations[tileID] ?? String(localized: "“\(text)” doesn’t fit this sentence.")
            )
        default:
            return nil
        }
    }

    private static func recall(_ feedback: SessionFeedback?, word: VocabularyItem) -> FeedbackCopy? {
        switch feedback {
        case .recallCorrect(let outcome):
            return FeedbackCopy(kind: .success, title: title(for: outcome), message: message(for: outcome, word: word))
        case .recallIncorrect(let submission, let remaining):
            return FeedbackCopy(
                kind: .error,
                title: String(localized: "Not quite"),
                message: String(localized: "“\(submission)” isn’t the word that means “\(word.meaningVi)” here. \(remaining) attempts left — a hint can help.")
            )
        case .recallRevealed:
            return FeedbackCopy(
                kind: .info,
                title: String(localized: "The answer is “\(word.term)”"),
                message: String(localized: "\(word.example) It’s added to your words to review.")
            )
        default:
            return nil
        }
    }

    private static func title(for outcome: RecallOutcome) -> String {
        switch outcome {
        case .unaidedRecall: String(localized: "Remembered!")
        case .hintedRecall: String(localized: "Correct, with hints")
        case .recalledAfterRetry: String(localized: "Correct on a retry")
        case .notRecalled: String(localized: "Not recalled")
        }
    }

    private static func message(for outcome: RecallOutcome, word: VocabularyItem) -> String {
        switch outcome {
        case .unaidedRecall: String(localized: "Perfect recall — first try, no hints.")
        case .hintedRecall: String(localized: "You used hints, so “\(word.term)” is listed for review.")
        case .recalledAfterRetry: String(localized: "It took more than one try, so “\(word.term)” is listed for review.")
        case .notRecalled: String(localized: "“\(word.term)” is listed for review.")
        }
    }
}
