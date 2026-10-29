import Foundation
import Observation

@Observable
@MainActor
final class ProgressStore {
    enum RunKind {
        case learn, review
    }

    private(set) var progress: LearningProgress
    /// What the next finished session counts as. Set by Home right before starting it.
    private var pendingRun: RunKind = .learn

    @ObservationIgnored private let defaults: UserDefaults?
    @ObservationIgnored let calendar: Calendar
    @ObservationIgnored private let now: () -> Date
    private static let key = "learningProgress"

    /// Pass `nil` defaults for an in-memory store (previews, tests).
    init(defaults: UserDefaults? = .standard, calendar: Calendar = .current, now: @escaping () -> Date = Date.init) {
        self.defaults = defaults
        self.calendar = calendar
        self.now = now
        progress = defaults?.data(forKey: Self.key)
            .flatMap { try? JSONDecoder().decode(LearningProgress.self, from: $0) } ?? LearningProgress()
    }

    var today: Date { now() }

    func status(for preferences: LearningPreferences, on date: Date) -> TodayStatus {
        TodayStatus.make(preferences: preferences, progress: progress, date: date, calendar: calendar)
    }

    func weekly(on date: Date) -> WeeklyProgress {
        WeeklyProgress.make(progress: progress, date: date, calendar: calendar)
    }

    func isDue(_ word: LearnedWord, on date: Date) -> Bool {
        word.lastPracticedAt < calendar.startOfDay(for: date)
    }

    func oftenMissedCount(on date: Date) -> Int {
        progress.oftenMissedCount(on: date, calendar: calendar)
    }

    func beginRun(_ kind: RunKind) {
        pendingRun = kind
    }

    /// Called when a session reaches Results. The demo session reuses the same words, so every
    /// learn run counts toward today's goal; a real content feed would serve new words each run.
    func recordFinishedRun(words: [VocabularyItem], result: SessionResult) {
        let date = now()
        switch pendingRun {
        case .learn: progress.recordLearned(words, at: date, calendar: calendar)
        case .review: progress.recordReviewed(at: date, calendar: calendar)
        }
        let missed = result.words.filter { $0.recallOutcome == .notRecalled || $0.recallOutcome == .recalledAfterRetry }
        progress.recordRecallMisses(missed.map(\.wordID), at: date)
        save()
    }

    private func save() {
        defaults?.set(try? JSONEncoder().encode(progress), forKey: Self.key)
    }
}
