import Foundation
import Observation

/// Runs one placement test. Nothing is scored here and nothing is shown as right or wrong:
/// the answers go up together at the end, and the backend saves the level it works out.
@Observable
@MainActor
final class PlacementTestStore {
    enum Stage: Equatable {
        case idle
        case loading
        /// Not enough content for a test yet; the learner picks a level by hand.
        case noContent
        case loadFailed(String)
        case answering
        case submitting
        case submitFailed(String, canRetry: Bool)
        case finished(PlacementResult)
    }

    private(set) var stage: Stage = .idle
    private(set) var questions: [PlacementQuestion] = []
    private(set) var index = 0
    private(set) var selectedOptionID: String?
    /// Runs once the backend has saved a level, so anything showing the level can catch up.
    var onPlaced: (() async -> Void)?

    private var answers: [PlacementAnswer] = []
    /// Bumped by every start and cancel, so an answer for an abandoned test is ignored.
    private var generation = 0
    private let api: VocabAPI
    private let haptics: FeedbackProviding

    init(api: VocabAPI, haptics: FeedbackProviding) {
        self.api = api
        self.haptics = haptics
    }

    var currentQuestion: PlacementQuestion? { questions.indices.contains(index) ? questions[index] : nil }
    var isOnLastQuestion: Bool { index == questions.count - 1 }

    /// Clears the previous run before returning, so a screen opened right after never shows it.
    @discardableResult
    func start() -> Task<Void, Never> {
        generation += 1
        let generation = generation
        questions = []
        answers = []
        index = 0
        selectedOptionID = nil
        stage = .loading
        return Task {
            do {
                let questions = try await api.placementTest()
                guard generation == self.generation else { return }
                self.questions = questions
                stage = questions.isEmpty ? .noContent : .answering
            } catch {
                guard generation == self.generation else { return }
                stage = .loadFailed(error.asAPIError.userMessage)
            }
        }
    }

    /// Leaves the on-screen stage alone: this runs while the test is animating away.
    func cancel() {
        generation += 1
    }

    func select(_ optionID: String) {
        guard stage == .answering, optionID != selectedOptionID else { return }
        selectedOptionID = optionID
        haptics.selectionChanged()
    }

    /// Locks in the selected option. Each question is answered once, with no going back.
    func confirmAnswer() async {
        guard let selectedOptionID else { return }
        await record(optionID: selectedOptionID)
    }

    /// Goes up as "don't know", which keeps a guess from placing the learner too high.
    func skipQuestion() async {
        haptics.selectionChanged()
        await record(optionID: nil)
    }

    private func record(optionID: String?) async {
        guard stage == .answering, let question = currentQuestion else { return }
        answers.append(PlacementAnswer(questionId: question.id, optionId: optionID))
        selectedOptionID = nil
        if isOnLastQuestion {
            await submit()
        } else {
            index += 1
        }
    }

    func retrySubmit() async {
        guard case .submitFailed(_, canRetry: true) = stage else { return }
        await submit()
    }

    private func submit() async {
        let generation = generation
        stage = .submitting
        do {
            let result = try await api.submitPlacementTest(answers)
            guard generation == self.generation else { return }
            stage = .finished(result)
            haptics.success()
            await onPlaced?()
        } catch {
            guard generation == self.generation else { return }
            let failure = error.asAPIError
            stage = .submitFailed(failure.userMessage, canRetry: failure.isRetryable)
        }
    }
}
