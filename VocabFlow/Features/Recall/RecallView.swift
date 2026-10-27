import SwiftUI

struct RecallView: View {
    let index: Int
    @Environment(SessionStore.self) private var store
    @Environment(\.motion) private var motion
    @State private var text = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        if let prompt = store.recallPrompt(at: index), let word = store.word(id: prompt.wordID) {
            screen(prompt: prompt, word: word)
        }
    }

    private func screen(prompt: RecallPrompt, word: VocabularyItem) -> some View {
        let resolved = store.recallOutcome(wordID: word.id) != nil
        let hintsUsed = store.hintsUsed(wordID: word.id)
        let total = store.content.recallPrompts.count

        return FlowScaffold(stage: "Recall", stageCurrent: index + 1, stageTotal: total) {
            VStack(spacing: Spacing.l) {
                StageIntro(
                    number: 3,
                    label: "Recall time",
                    title: String(localized: "You’ve got this."),
                    subtitle: "Can you remember it without hints?"
                )

                questionCard(prompt: prompt, word: word, resolved: resolved)

                RecallInput(text: $text, isFocused: $isFocused, isEnabled: !resolved) {
                    check(wordID: word.id)
                }

                HintControl(
                    hintsUsed: hintsUsed,
                    maxHints: HintSequence.maxHints,
                    hints: resolved ? [] : (0..<hintsUsed).compactMap { HintSequence.hint(for: word.term, level: $0 + 1) },
                    isEnabled: !resolved,
                    onHint: { store.requestHint() },
                    onReveal: {
                        store.revealAnswer()
                        isFocused = false
                    }
                )

                feedback(word: word)
                    .animation(motion.animation(MotionTokens.feedback), value: store.state.feedback)
            }
        } action: {
            action(resolved: resolved, wordID: word.id, isLast: index + 1 >= total)
        }
    }

    private func questionCard(prompt: RecallPrompt, word: VocabularyItem, resolved: Bool) -> some View {
        VStack(spacing: Spacing.m) {
            Eyebrow(text: "What’s the word?")
            Text(verbatim: word.meaningVi)
                .font(Typography.screenTitle)
                .tracking(-0.7)
                .foregroundStyle(Color.ink)
                .multilineTextAlignment(.center)
                .accessibilityLabel(Text("Meaning: \(word.meaningVi)"))
            Text(sentence(prompt, word: word, resolved: resolved))
                .font(Typography.body)
                .foregroundStyle(Color.mutedInk)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityLabel(Text(prompt.sentence.replacingOccurrences(of: BuildChallenge.blank, with: resolved ? word.term : String(localized: "blank"))))
        }
        .padding(.horizontal, Spacing.l)
        .padding(.top, Spacing.xl + 4)
        .padding(.bottom, Spacing.xl)
        .cardSurface(accent: .primarySoft)
    }

    @ViewBuilder
    private func action(resolved: Bool, wordID: String, isLast: Bool) -> some View {
        if resolved {
            PrimaryButton(title: isLast ? "See results" : "Continue") {
                motion.perform(MotionTokens.transition) { store.next() }
            }
        } else {
            let submission = AnswerEvaluator.normalize(text)
            let unchanged: Bool = {
                if case .recallIncorrect(let previous, _) = store.state.feedback { return previous == submission }
                return false
            }()
            PrimaryButton(
                title: "Check answer",
                requirement: unchanged ? "Change your answer before checking again." : "Type a word to check.",
                isEnabled: !submission.isEmpty && !unchanged
            ) {
                check(wordID: wordID)
            }
        }
    }

    @ViewBuilder
    private func feedback(word: VocabularyItem) -> some View {
        switch store.state.feedback {
        case .recallCorrect(let outcome):
            FeedbackBanner(kind: .success, title: title(for: outcome), message: message(for: outcome, word: word))
                .transition(motion.popTransition)
        case .recallIncorrect(let submission, let remaining):
            FeedbackBanner(
                kind: .error,
                title: String(localized: "Not quite"),
                message: String(localized: "“\(submission)” isn’t the word that means “\(word.meaningVi)” here. \(remaining) attempts left — a hint can help.")
            )
            .transition(motion.popTransition)
        case .recallRevealed:
            FeedbackBanner(
                kind: .info,
                title: String(localized: "The answer is “\(word.term)”"),
                message: String(localized: "\(word.example) It’s added to your words to review.")
            )
            .transition(motion.popTransition)
        default:
            EmptyView()
        }
    }

    private func check(wordID: String) {
        store.submitRecall(text: text)
        if store.recallOutcome(wordID: wordID) != nil {
            isFocused = false
        }
    }

    private func title(for outcome: RecallOutcome) -> String {
        switch outcome {
        case .unaidedRecall: String(localized: "Remembered!")
        case .hintedRecall: String(localized: "Correct, with hints")
        case .recalledAfterRetry: String(localized: "Correct on a retry")
        case .notRecalled: String(localized: "Not recalled")
        }
    }

    private func message(for outcome: RecallOutcome, word: VocabularyItem) -> String {
        switch outcome {
        case .unaidedRecall: String(localized: "Perfect recall — first try, no hints.")
        case .hintedRecall: String(localized: "You used hints, so “\(word.term)” is listed for review.")
        case .recalledAfterRetry: String(localized: "It took more than one try, so “\(word.term)” is listed for review.")
        case .notRecalled: String(localized: "“\(word.term)” is listed for review.")
        }
    }

    private func sentence(_ prompt: RecallPrompt, word: VocabularyItem, resolved: Bool) -> AttributedString {
        let parts = prompt.sentence.components(separatedBy: BuildChallenge.blank)
        var result = AttributedString(parts.first ?? "")
        var middle = AttributedString(resolved ? word.term : "_____")
        middle.foregroundColor = resolved ? Color.primarySoftInk : Color.mutedInk
        middle.inlinePresentationIntent = resolved ? .stronglyEmphasized : nil
        result += middle
        result += AttributedString(parts.dropFirst().joined(separator: BuildChallenge.blank))
        return result
    }
}
