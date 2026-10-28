import Foundation
import Observation

@Observable
@MainActor
final class SessionStore {
    private(set) var state = SessionState()
    private(set) var sessionToken = UUID()
    let content: DemoContent
    let haptics: FeedbackProviding
    /// Runs once each time a session reaches Results.
    var onFinish: (@MainActor () -> Void)?

    init(content: DemoContent, haptics: FeedbackProviding) {
        self.content = content
        self.haptics = haptics
    }

    func start() { send(.start) }
    func finishLearning() { send(.learnedNext) }
    func submitBuild(tileID: String) { send(.buildSubmitted(tileID: tileID)) }
    func submitRecall(text: String) { send(.recallSubmitted(text)) }
    func requestHint() { send(.hintRequested) }
    func revealAnswer() { send(.answerRevealed) }
    func dismissFeedback() { send(.feedbackDismissed) }
    func next() { send(.advance) }
    func restart() { send(.restart) }

    func playAgain() {
        send(.restart)
        send(.start)
    }

    var totalWords: Int { content.words.count }

    func word(id: String) -> VocabularyItem? { content.word(id: id) }

    func buildChallenge(at index: Int) -> BuildChallenge? {
        content.buildChallenges.indices.contains(index) ? content.buildChallenges[index] : nil
    }

    func recallPrompt(at index: Int) -> RecallPrompt? {
        content.recallPrompts.indices.contains(index) ? content.recallPrompts[index] : nil
    }

    func isBuildCompleted(index: Int) -> Bool {
        SessionReducer.isBuildCompleted(index: index, state: state, content: content)
    }

    func hintsUsed(wordID: String) -> Int { state.hintsByWordID[wordID, default: 0] }
    func recallOutcome(wordID: String) -> RecallOutcome? { state.recallOutcomes[wordID] }
    var result: SessionResult { SessionReducer.result(state: state, content: content) }

    /// Progress is split into two stages: meeting the words, then practising them.
    var flowProgress: (stage: FlowStage, current: Int, total: Int) {
        let learn = content.words.count
        let build = content.buildChallenges.count
        let practice = build + content.recallPrompts.count
        switch state.phase {
        case .home: return (.learn, 0, learn)
        case .learn(let index): return (.learn, index + 1, learn)
        case .build(let index): return (.practice, index + 1, practice)
        case .recall(let index): return (.practice, build + index + 1, practice)
        case .results: return (.practice, practice, practice)
        }
    }

    private func send(_ action: SessionAction) {
        let transition = SessionReducer.reduce(state: state, action: action, content: content)
        state = transition.state
        for event in transition.events {
            emit(event)
        }
    }

    private func emit(_ event: SessionEvent) {
        switch event {
        case .correct: haptics.success()
        case .incorrect: haptics.error()
        case .hintOpened, .answerRevealed: haptics.selectionChanged()
        case .restarted: sessionToken = UUID()
        case .finished: onFinish?()
        case .started, .advanced: break
        }
    }
}

enum FlowStage: Equatable {
    case learn, practice
}
