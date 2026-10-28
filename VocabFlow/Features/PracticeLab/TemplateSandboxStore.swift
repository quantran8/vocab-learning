import Foundation
import Observation

/// Owns Practice Lab navigation and ephemeral template runs. Never writes to `SessionStore`;
/// it holds its own copy of the words so no counters are shared with the scored session.
@Observable
@MainActor
final class TemplateSandboxStore {
    let library: TemplateLibrary
    let words: [VocabularyItem]
    let haptics: FeedbackProviding
    let speech: SpeechProviding

    private(set) var isOpen = false
    var category: TemplateCategory?
    private(set) var activeTemplate: TemplateKind?
    private(set) var exerciseIndex = 0
    private(set) var run: TemplateRun?
    private(set) var runToken = UUID()
    /// Changes on "Try again"; views holding input after Check (placed tile, typed text) clear it.
    private(set) var attemptToken = UUID()

    init(library: TemplateLibrary, words: [VocabularyItem], haptics: FeedbackProviding, speech: SpeechProviding) {
        self.library = library
        self.words = words
        self.haptics = haptics
        self.speech = speech
    }

    var visibleTemplates: [TemplateDefinition] {
        guard let category else { return library.templates }
        return library.templates.filter { $0.category == category }
    }

    var activeDefinition: TemplateDefinition? { activeTemplate.flatMap(library.template) }

    var hasNextExercise: Bool {
        guard let definition = activeDefinition else { return false }
        return exerciseIndex + 1 < definition.exercises.count
    }

    func word(id: String) -> VocabularyItem? { words.first { $0.id == id } }

    // MARK: Navigation

    func openLab() {
        isOpen = true
    }

    func closeLab() {
        closeTemplate()
        isOpen = false
    }

    /// Baseline reset policy: every entry starts a fresh run.
    func open(_ kind: TemplateKind) {
        activeTemplate = kind
        startRun(exerciseIndex: 0)
    }

    func closeTemplate() {
        speech.stop()
        activeTemplate = nil
        run = nil
        runToken = UUID()
    }

    func retry() { startRun(exerciseIndex: exerciseIndex) }

    func tryAgain() {
        guard run?.phase == .incorrect else { return }
        mutate { $0.dismissFeedback() }
        attemptToken = UUID()
    }

    func nextExercise() {
        guard hasNextExercise else { return }
        startRun(exerciseIndex: exerciseIndex + 1)
    }

    // MARK: Intents

    func submitChoice(_ id: String) { mutate { $0.submitChoice(id) } }
    func submitText(_ text: String) { mutate { $0.submitText(text) } }
    func requestHint() { mutate { $0.requestHint() } }
    func reveal() { mutate { $0.reveal() } }
    func selectPair(wordID: String, glossWordID: String) { mutate { $0.selectPair(wordID: wordID, glossWordID: glossWordID) } }
    func locateLetter(at index: Int) { mutate { $0.locateLetter(at: index) } }
    func repairLetter(with replacement: String) { mutate { $0.repairLetter(with: replacement) } }
    func submitStress(_ index: Int) { mutate { $0.submitStress(index) } }
    func selfCheck() { mutate { $0.selfCheck() } }

    /// User-triggered only. Falls back to a written cue when speech can't start.
    func playAudio() {
        guard let run else { return }
        if speech.speak(run.exercise.audioText ?? run.word.term) {
            mutate { $0.recordAudioPlayed() }
        } else {
            useAudioFallback()
        }
    }

    func useAudioFallback() {
        speech.stop()
        self.run?.useAudioFallback()
    }

    // MARK: Private

    private func startRun(exerciseIndex index: Int) {
        speech.stop()
        guard let definition = activeDefinition, definition.exercises.indices.contains(index) else {
            run = nil
            return
        }
        let exercise = definition.exercises[index]
        guard let word = word(id: exercise.wordID) else {
            run = nil
            return
        }
        exerciseIndex = index
        run = TemplateRun(
            kind: definition.id,
            exercise: exercise,
            word: word,
            pairWords: (exercise.pairWordIDs ?? []).compactMap(self.word(id:))
        )
        runToken = UUID()
    }

    private func mutate(_ body: (inout TemplateRun) -> [TemplateEvent]) {
        guard var current = run else { return }
        let events = body(&current)
        run = current
        for event in events {
            switch event {
            case .correct: haptics.success()
            case .incorrect: haptics.error()
            case .progressed, .hintOpened, .revealed, .selfChecked: haptics.selectionChanged()
            case .audioPlayed: break
            }
        }
    }
}
