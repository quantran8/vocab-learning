import Foundation

/// What the learner chose during onboarding. Weekdays use `Calendar` numbering (1 = Sunday … 7 = Saturday).
struct LearningPreferences: Codable, Equatable {
    /// Matches the backend's `dailyNewWordGoal` limits.
    static let wordsPerDayRange = 1...30
    static let allWeekdays: Set<Int> = Set(1...7)

    /// One collection at a time; `topicIDs` always belong to it.
    var collectionID: String
    var topicIDs: Set<String>
    var wordsPerDay: Int
    var learningDays: Set<Int>
    var reminderEnabled: Bool
    var reminderHour: Int
    var reminderMinute: Int

    private enum CodingKeys: String, CodingKey {
        case collectionID, topicIDs, wordsPerDay, learningDays, reminderEnabled, reminderHour, reminderMinute
    }

    static let `default` = LearningPreferences(
        collectionID: "everyday",
        topicIDs: ["everyday-english", "travel"],
        wordsPerDay: 5,
        learningDays: [2, 3, 4, 5, 6],
        reminderEnabled: true,
        reminderHour: 20,
        reminderMinute: 0
    )

    var collection: VocabCollection? { TopicCatalog.collection(id: collectionID) }

    var isComplete: Bool {
        collection != nil && !topicIDs.isEmpty && !learningDays.isEmpty && Self.wordsPerDayRange.contains(wordsPerDay)
    }

    var isEveryDay: Bool { learningDays == Self.allWeekdays }
    /// Sessions per Journey segment: one per learning day.
    var weeklySessionGoal: Int { learningDays.count }

    /// Today's date at the reminder time; only the hour and minute are meaningful.
    var reminderDate: Date {
        Calendar.current.date(bySettingHour: reminderHour, minute: reminderMinute, second: 0, of: .now) ?? .now
    }

    mutating func adjustWordsPerDay(by amount: Int) {
        let range = Self.wordsPerDayRange
        wordsPerDay = min(range.upperBound, max(range.lowerBound, wordsPerDay + amount))
    }

    /// Topics are collection-specific, so switching collections starts the topic choice over.
    mutating func selectCollection(_ id: String) {
        guard id != collectionID, TopicCatalog.collection(id: id) != nil else { return }
        collectionID = id
        topicIDs = []
    }

    mutating func toggleTopic(_ id: String) {
        guard collection?.topicIDs.contains(id) == true else { return }
        if topicIDs.contains(id) { topicIDs.remove(id) } else { topicIDs.insert(id) }
    }

    var hasAllTopics: Bool {
        guard let collection else { return false }
        return topicIDs == collection.topicIDs
    }

    /// "Select all" when some topics are missing, "Clear all" when all are selected.
    mutating func toggleAllTopics() {
        topicIDs = hasAllTopics ? [] : collection?.topicIDs ?? []
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

extension LearningPreferences {
    /// Plans saved before collections existed have no `collectionID`: file them under the collection of
    /// the first collection holding any of their topics and drop topics from other collections.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let topicIDs = try container.decode(Set<String>.self, forKey: .topicIDs)
        if let collectionID = try container.decodeIfPresent(String.self, forKey: .collectionID) {
            self.collectionID = collectionID
            self.topicIDs = topicIDs
        } else {
            let collection = TopicCatalog.collections.first { !$0.topicIDs.isDisjoint(with: topicIDs) }
            self.collectionID = collection?.id ?? Self.default.collectionID
            self.topicIDs = topicIDs.intersection(collection?.topicIDs ?? [])
        }
        wordsPerDay = min(try container.decode(Int.self, forKey: .wordsPerDay), Self.wordsPerDayRange.upperBound)
        learningDays = try container.decode(Set<Int>.self, forKey: .learningDays)
        reminderEnabled = try container.decode(Bool.self, forKey: .reminderEnabled)
        reminderHour = try container.decode(Int.self, forKey: .reminderHour)
        reminderMinute = try container.decode(Int.self, forKey: .reminderMinute)
    }
}
