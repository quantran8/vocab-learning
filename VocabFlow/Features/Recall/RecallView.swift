import SwiftUI

/// Recall stage content. Header and the Check/Continue action live in `SessionFlowView`.
struct RecallView: View {
    let index: Int
    @Environment(SessionStore.self) private var store
    @Environment(FlowDraft.self) private var draft
    @FocusState private var isFocused: Bool

    var body: some View {
        if let prompt = store.recallPrompt(at: index), let word = store.word(id: prompt.wordID) {
            content(prompt: prompt, word: word)
        }
    }

    private func content(prompt: RecallPrompt, word: VocabularyItem) -> some View {
        @Bindable var draft = draft
        let outcome = store.recallOutcome(wordID: word.id)
        let resolved = outcome != nil
        // While a wrong answer is shown, input waits for "Try again".
        let isLocked: Bool = {
            if case .recallIncorrect = store.state.feedback { return true }
            return false
        }()
        let hintsUsed = store.hintsUsed(wordID: word.id)

        return VStack(spacing: Spacing.l) {
            StageIntro(
                number: 3,
                label: "Recall time",
                title: String(localized: "You’ve got this."),
                subtitle: "Can you remember it without hints?"
            )

            questionCard(prompt: prompt, word: word, resolved: resolved)

            // Once resolved, show the last submission instead of the draft, which is cleared on Continue.
            RecallInput(text: resolved ? .constant(lastSubmission(wordID: word.id)) : $draft.recallText, isFocused: $isFocused, isEnabled: !resolved && !isLocked) {
                store.submitRecall(text: draft.recallText)
            }

            HintControl(
                hintsUsed: hintsUsed,
                maxHints: HintSequence.maxHints,
                hints: resolved ? [] : (0..<hintsUsed).compactMap { HintSequence.hint(for: word.term, level: $0 + 1) },
                isEnabled: !resolved && !isLocked,
                onHint: { store.requestHint() },
                onReveal: { store.revealAnswer() }
            )
        }
        // Covers both the pinned Check button and the keyboard submit.
        .onChange(of: outcome) { _, newOutcome in
            if newOutcome != nil { isFocused = false }
        }
        .onChange(of: isLocked) { _, locked in
            // Back from "Try again": ready to type immediately.
            isFocused = !locked && !resolved
        }
    }

    private func lastSubmission(wordID: String) -> String {
        store.state.attempts.last { $0.stage == .recall && $0.wordID == wordID }?.submission ?? ""
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
        .cardSurface(accent: .interactive)
    }

    private func sentence(_ prompt: RecallPrompt, word: VocabularyItem, resolved: Bool) -> AttributedString {
        let parts = prompt.sentence.components(separatedBy: BuildChallenge.blank)
        var result = AttributedString(parts.first ?? "")
        var middle = AttributedString(resolved ? word.term : "_____")
        middle.foregroundColor = resolved ? Color.selectedInk : Color.mutedInk
        middle.inlinePresentationIntent = resolved ? .stronglyEmphasized : nil
        result += middle
        result += AttributedString(parts.dropFirst().joined(separator: BuildChallenge.blank))
        return result
    }
}
