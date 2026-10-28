import Foundation

/// What the learner chose during onboarding. Weekdays use `Calendar` numbering (1 = Sunday … 7 = Saturday).
struct LearningPreferences: Codable, Equatable {
    static let wordsPerDayRange = 1...50
    static let allWeekdays: Set<Int> = Set(1...7)

    var topicIDs: Set<String>
    var wordsPerDay: Int
    var learningDays: Set<Int>
    var reminderEnabled: Bool
    var reminderHour: Int
    var reminderMinute: Int

    static let `default` = LearningPreferences(
        topicIDs: ["everyday-english", "business"],
        wordsPerDay: 5,
        learningDays: [2, 3, 4, 5, 6],
        reminderEnabled: true,
        reminderHour: 20,
        reminderMinute: 0
    )

    var isComplete: Bool {
        !topicIDs.isEmpty && !learningDays.isEmpty && Self.wordsPerDayRange.contains(wordsPerDay)
    }

    var isEveryDay: Bool { learningDays == Self.allWeekdays }

    /// Today's date at the reminder time; only the hour and minute are meaningful.
    var reminderDate: Date {
        Calendar.current.date(bySettingHour: reminderHour, minute: reminderMinute, second: 0, of: .now) ?? .now
    }

    mutating func adjustWordsPerDay(by amount: Int) {
        let range = Self.wordsPerDayRange
        wordsPerDay = min(range.upperBound, max(range.lowerBound, wordsPerDay + amount))
    }

    mutating func toggleTopic(_ id: String) {
        if topicIDs.contains(id) { topicIDs.remove(id) } else { topicIDs.insert(id) }
    }

    mutating func toggleDay(_ weekday: Int) {
        guard Self.allWeekdays.contains(weekday) else { return }
        if learningDays.contains(weekday) { learningDays.remove(weekday) } else { learningDays.insert(weekday) }
    }

    /// "Every day" when some days are missing, "Clear all" when all are selected.
    mutating func toggleEveryDay() {
        learningDays = isEveryDay ? [] : Self.allWeekdays
    }
}
