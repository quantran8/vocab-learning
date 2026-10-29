import XCTest
@testable import VocabFlow

final class TodayStatusTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

    /// Wednesday 2026-10-28 09:00 UTC.
    private var wednesday: Date { date(day: 28, hour: 9) }

    private func date(day: Int, hour: Int) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 10, day: day, hour: hour))!
    }

    private func words(_ count: Int) -> [VocabularyItem] {
        (0..<count).map { VocabularyItem(id: "w\($0)", term: "word\($0)", meaningVi: "nghĩa \($0)", example: "") }
    }

    private func status(_ progress: LearningProgress, goal: Int = 5, days: Set<Int> = [2, 3, 4, 5, 6], on date: Date? = nil) -> TodayStatus {
        var preferences = LearningPreferences.default
        preferences.wordsPerDay = goal
        preferences.learningDays = days
        return TodayStatus.make(preferences: preferences, progress: progress, date: date ?? wednesday, calendar: calendar)
    }

    func testFreshDayIsReadyToLearn() {
        let result = status(LearningProgress())
        XCTAssertEqual(result.mode, .learning)
        XCTAssertEqual(result.remaining, 5)
        XCTAssertEqual(result.due, 0)
    }

    func testLearningTodayCountsTowardGoalThenCompletes() {
        var progress = LearningProgress()
        progress.recordLearned(words(3), at: wednesday, calendar: calendar)
        XCTAssertEqual(status(progress).mode, .learning)
        XCTAssertEqual(status(progress).introduced, 3)

        progress.recordLearned(words(3), at: wednesday, calendar: calendar)
        let done = status(progress)
        XCTAssertEqual(done.mode, .completed)
        XCTAssertEqual(done.introduced, 5, "Capped at the goal")
        XCTAssertEqual(progress.learnedWords.count, 3, "Same words are not listed twice")
    }

    func testYesterdaysWordsAreDueAndCountResets() {
        var progress = LearningProgress()
        progress.recordLearned(words(3), at: date(day: 27, hour: 20), calendar: calendar)
        let today = status(progress)
        XCTAssertEqual(today.introduced, 0)
        XCTAssertEqual(today.due, 3)
        XCTAssertEqual(today.mode, .learning, "Backlog smaller than the goal keeps the learn focus")
    }

    func testLargeBacklogSwitchesToReviewFocus() {
        var progress = LearningProgress()
        progress.recordLearned(words(6), at: date(day: 27, hour: 20), calendar: calendar)
        XCTAssertEqual(status(progress).mode, .reviewFocus)

        progress.recordReviewed(at: wednesday, calendar: calendar)
        XCTAssertEqual(status(progress).due, 0)
        XCTAssertEqual(status(progress).mode, .learning)
    }

    func testNonLearningDayIsRestButKeepsReviews() {
        var progress = LearningProgress()
        progress.recordLearned(words(2), at: date(day: 27, hour: 20), calendar: calendar)
        let rest = status(progress, days: [2])
        XCTAssertEqual(rest.mode, .rest)
        XCTAssertEqual(rest.due, 2)
    }

    func testWordSearchMatchesTermOrMeaningIgnoringCaseAndDiacritics() {
        let word = LearnedWord(id: "adapt", term: "adapt", meaning: "thích nghi", learnedAt: wednesday, lastPracticedAt: wednesday)
        XCTAssertTrue(word.matches(""))
        XCTAssertTrue(word.matches("  ADA "))
        XCTAssertTrue(word.matches("thich"))
        XCTAssertTrue(word.matches("nghi"))
        XCTAssertFalse(word.matches("sustain"))
    }

    func testWeeklyCountsOnlyWordsFirstLearnedThisWeek() {
        var progress = LearningProgress()
        progress.recordLearned(words(2), at: date(day: 24, hour: 9), calendar: calendar)
        progress.recordLearned(Array(words(5).dropFirst(2)), at: wednesday, calendar: calendar)
        let weekly = WeeklyProgress.make(progress: progress, date: wednesday, calendar: calendar)
        XCTAssertEqual(weekly.day, 4)
        XCTAssertEqual(weekly.daysUntilOpen, 3)
        XCTAssertEqual(weekly.wordsLearned, 3)
    }
}
