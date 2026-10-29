import SwiftUI

/// Hosts any template. Knows the shared frame and lifecycle, never the answer rules.
struct TemplateHostView: View {
    @Environment(TemplateSandboxStore.self) private var sandbox

    var body: some View {
        if let run = sandbox.run {
            content(run)
                .id(sandbox.runToken)
        }
    }

    @ViewBuilder
    private func content(_ run: TemplateRun) -> some View {
        switch run.kind {
        case .select: SelectMeaningView(run: run)
        case .match: MatchingPairsView(run: run)
        case .stack: WordStackView(run: run)
        case .audioSelect: AudioSelectView(run: run)
        case .typing: RecallTypingView(run: run)
        case .surgery: LetterSurgeryView(run: run)
        case .split: SoundSplitView(run: run)
        case .trace: AudioTraceView(run: run)
        case .echo: EchoBackView(run: run)
        }
    }
}

/// Practice scaffold: close + progress → instruction → one central object → feedback → pinned action.
struct TemplateFrame<Content: View, Action: View>: View {
    let run: TemplateRun
    /// Overrides the exercise prompt as heading when the prompt itself is the sentence being solved.
    var instruction: LocalizedStringKey?
    var isScrollDisabled = false
    @ViewBuilder let content: Content
    @ViewBuilder let action: Action

    @Environment(TemplateSandboxStore.self) private var sandbox
    @Environment(\.motion) private var motion

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.l) {
                ExerciseHeading(title: heading, subtitle: subtitle)

                // While a wrong answer is shown, the exercise waits for "Try again".
                content
                    .allowsHitTesting(run.phase != .incorrect)
            }
            .padding(.horizontal, Spacing.screenGutter)
            .padding(.top, Spacing.m)
            .padding(.bottom, Spacing.l)
        }
        .scrollDisabled(isScrollDisabled)
        .scrollDismissesKeyboard(.interactively)
        .safeAreaInset(edge: .top) {
            FlowHeader(
                stage: "Practice Lab",
                stageCurrent: sandbox.exerciseIndex + 1,
                stageTotal: exerciseCount,
                step: sandbox.exerciseIndex + 1,
                totalSteps: exerciseCount,
                closeLabel: "Back to Lab",
                onClose: { motion.perform(MotionTokens.transition) { sandbox.closeTemplate() } }
            )
            .padding(.horizontal, Spacing.screenGutter)
            .padding(.vertical, Spacing.xs)
            .background(Color.canvas)
        }
        .safeAreaInset(edge: .bottom) {
            FeedbackActionPanel(feedback: TemplateFeedbackCopy.make(run)) { action }
        }
        .onDisappear { sandbox.speech.stop() }
    }

    private var heading: Text {
        instruction.map { Text($0) } ?? Text(verbatim: run.exercise.prompt)
    }

    /// Template name, plus the variant when it isn't the base framing.
    private var subtitle: Text? {
        guard let title = sandbox.activeDefinition?.title else { return nil }
        guard let variant = run.exercise.variant?.chipTitle else { return Text(verbatim: title) }
        return Text(verbatim: "\(title) · ") + Text(variant)
    }

    private var exerciseCount: Int {
        sandbox.activeDefinition?.exercises.count ?? 1
    }
}

/// Shared lifecycle: Check while open, then Next / Practise again / Back once finished.
struct TemplateActionBar: View {
    let run: TemplateRun
    var checkTitle: LocalizedStringKey = "Check"
    var canCheck = false
    /// Status line shown in place of the button when there is no Check (e.g. Matching Pairs).
    var requirement: LocalizedStringKey?
    var onCheck: (() -> Void)?

    @Environment(TemplateSandboxStore.self) private var sandbox
    @Environment(\.motion) private var motion

    var body: some View {
        if run.phase.isFinished {
            VStack(spacing: Spacing.s) {
                if sandbox.hasNextExercise {
                    PrimaryButton(title: "Next example") {
                        motion.perform(MotionTokens.transition) { sandbox.nextExercise() }
                    }
                } else {
                    PrimaryButton(title: "Back to Lab") {
                        motion.perform(MotionTokens.transition) { sandbox.closeTemplate() }
                    }
                }
                SecondaryButton(title: "Practise again", systemImage: "arrow.clockwise") {
                    motion.perform(MotionTokens.transition) { sandbox.retry() }
                }
            }
        } else if run.phase == .incorrect {
            PrimaryButton(title: "Try again") {
                withAnimation(motion.animation(MotionTokens.feedback)) { sandbox.tryAgain() }
            }
        } else if let onCheck {
            PrimaryButton(title: checkTitle, isEnabled: canCheck, action: onCheck)
        } else if let requirement {
            Text(requirement)
                .font(Typography.secondary)
                .foregroundStyle(Color.mutedInk)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, minHeight: Spacing.minTouchTarget)
        }
    }
}

/// Explanation for the current template feedback, shown in the pinned panel.
enum TemplateFeedbackCopy {
    static func make(_ run: TemplateRun) -> FeedbackCopy? {
        let exercise = run.exercise
        let word = run.word
        switch run.feedback {
        case nil:
            return nil
        case .correct:
            return FeedbackCopy(kind: .success, title: correctTitle(run), message: exercise.feedback)
        case .wrongChoice(let id):
            let text = exercise.choice(id: id)?.text ?? ""
            return FeedbackCopy(kind: .error, title: String(localized: "Not quite — try another"),
                    message: exercise.explanations?[id] ?? String(localized: "“\(text)” isn’t the answer here."))
        case .wrongTyped(let submission):
            return FeedbackCopy(kind: .error, title: String(localized: "Not quite"),
                    message: String(localized: "“\(submission)” isn’t the expected word here. Check the spelling, try again, or show the answer."))
        case .pairMatched(let wordID):
            let pair = run.pairWords.first { $0.id == wordID }
            return FeedbackCopy(kind: .success, title: String(localized: "Pair matched"),
                    message: String(localized: "\(pair?.term ?? "") — \(pair?.meaningVi ?? ""). Keep going."))
        case .pairMismatched(let wordID, let glossWordID):
            let term = run.pairWords.first { $0.id == wordID }?.term ?? ""
            let gloss = run.pairWords.first { $0.id == glossWordID }?.meaningVi ?? ""
            return FeedbackCopy(kind: .error, title: String(localized: "Not a pair"),
                    message: String(localized: "“\(term)” doesn’t mean “\(gloss)”. Your picks were reset — try another meaning."))
        case .letterLocated(let index):
            let letter = letter(run, at: index)
            return FeedbackCopy(kind: .info, title: String(localized: "Found it"),
                    message: String(localized: "Letter \(index + 1), “\(letter)”, is the mistake. Now choose the letter that fixes it."))
        case .wrongLetter(let index):
            let letter = letter(run, at: index)
            return FeedbackCopy(kind: .error, title: String(localized: "That letter is fine"),
                    message: String(localized: "Letter \(index + 1), “\(letter)”, is spelled correctly. Look for the one that doesn’t belong."))
        case .wrongRepair(let replacement):
            let result = exercise.wrongCharacterIndex.flatMap { TemplateEvaluator.repaired(exercise, index: $0, replacement: replacement) } ?? ""
            return FeedbackCopy(kind: .error, title: String(localized: "Right spot, wrong letter"),
                    message: String(localized: "That spells “\(result)”, which isn’t the word. Try another letter."))
        case .wrongStress(let index):
            let syllable = word.syllables.indices.contains(index) ? word.syllables[index] : ""
            return FeedbackCopy(kind: .error, title: String(localized: "Not that syllable"),
                    message: String(localized: "“\(syllable)” is unstressed — it’s shorter and quieter. Listen again and compare."))
        case .revealed:
            return FeedbackCopy(kind: .info, title: String(localized: "The answer is “\(word.term)”"), message: exercise.feedback)
        case .selfChecked:
            return FeedbackCopy(kind: .info, title: String(localized: "Marked as practised"), message: exercise.feedback)
        }
    }

    private static func correctTitle(_ run: TemplateRun) -> String {
        switch run.typedOutcome {
        case .unaidedRecall: String(localized: "Correct — first try, no help")
        case .hintedRecall: String(localized: "Correct, with hints")
        case .recalledAfterRetry: String(localized: "Correct on a retry")
        case .notRecalled, nil: String(localized: "Correct!")
        }
    }

    private static func letter(_ run: TemplateRun, at index: Int) -> String {
        let letters = run.exercise.misspellingLetters
        return letters.indices.contains(index) ? String(letters[index]) : ""
    }
}
