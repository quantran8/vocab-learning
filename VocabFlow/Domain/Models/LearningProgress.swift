import Foundation

struct LearnedWord: Codable, Equatable, Identifiable {
    let id: String
    let term: String
    let meaning: String
    let learnedAt: Date
    var lastPracticedAt: Date
}

/// Locally persisted learning history. A word is due for review once it hasn't been practised today.
struct LearningProgress: Codable, Equatable {
    var learnedWords: [LearnedWord] = []
    /// Start of the day `introducedCount` belongs to; any other day reads as zero.
    var countedDay: Date?
    var introducedCount = 0
    /// When each word's recall was missed (not recalled, or only after a retry). Optional so older saves decode.
    var recallMisses: [String: [Date]]?

    func introduced(on date: Date, calendar: Calendar) -> Int {
        guard let countedDay, calendar.isDate(countedDay, inSameDayAs: date) else { return 0 }
        return introducedCount
    }

    func dueWords(on date: Date, calendar: Calendar) -> [LearnedWord] {
        let startOfDay = calendar.startOfDay(for: date)
        return learnedWords.filter { $0.lastPracticedAt < startOfDay }
    }

    mutating func recordLearned(_ words: [VocabularyItem], at date: Date, calendar: Calendar) {
        introducedCount = introduced(on: date, calendar: calendar) + words.count
        countedDay = calendar.startOfDay(for: date)
        for word in words {
            if let index = learnedWords.firstIndex(where: { $0.id == word.id }) {
                learnedWords[index].lastPracticedAt = date
            } else {
                learnedWords.append(LearnedWord(
                    id: word.id,
                    term: word.term,
                    meaning: word.meaningVi,
                    learnedAt: date,
                    lastPracticedAt: date
                ))
            }
        }
    }

    mutating func recordRecallMisses(_ wordIDs: [String], at date: Date) {
        guard !wordIDs.isEmpty else { return }
        var misses = recallMisses ?? [:]
        for id in wordIDs {
            misses[id, default: []].append(date)
        }
        recallMisses = misses
    }

    /// Words missed at least twice within the last `days` days.
    func oftenMissedCount(on date: Date, days: Int = 30, calendar: Calendar) -> Int {
        guard let start = calendar.date(byAdding: .day, value: -days, to: date) else { return 0 }
        return (recallMisses ?? [:]).values.filter { $0.filter { $0 >= start }.count >= 2 }.count
    }

    mutating func recordReviewed(at date: Date, calendar: Calendar) {
        let due = Set(dueWords(on: date, calendar: calendar).map(\.id))
        for index in learnedWords.indices where due.contains(learnedWords[index].id) {
            learnedWords[index].lastPracticedAt = date
        }
    }
}

/// What Home shows today, derived from the plan and the history. Pure so every state is testable.
struct TodayStatus: Equatable {
    enum Mode: Equatable {
        /// Not a learning day; reviews stay available.
        case rest
        /// Nothing introduced yet and the review backlog is at least a day's goal.
        case reviewFocus
        case learning
        case completed
    }

    let mode: Mode
    let goal: Int
    let introduced: Int
    let due: Int

    var remaining: Int { max(0, goal - introduced) }
    var fraction: Double { goal > 0 ? Double(introduced) / Double(goal) : 0 }

    static func make(
        preferences: LearningPreferences,
        progress: LearningProgress,
        date: Date,
        calendar: Calendar
    ) -> TodayStatus {
        let goal = preferences.wordsPerDay
        let introduced = min(progress.introduced(on: date, calendar: calendar), goal)
        let due = progress.dueWords(on: date, calendar: calendar).count
        let mode: Mode
        if !preferences.learningDays.contains(calendar.component(.weekday, from: date)) {
            mode = .rest
        } else if introduced >= goal {
            mode = .completed
        } else if introduced == 0, due >= goal {
            mode = .reviewFocus
        } else {
            mode = .learning
        }
        return TodayStatus(mode: mode, goal: goal, introduced: introduced, due: due)
    }
}

extension LearnedWord {
    /// Case- and diacritic-insensitive match on the English term or the Vietnamese meaning.
    func matches(_ query: String) -> Bool {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !needle.isEmpty else { return true }
        let options: String.CompareOptions = [.caseInsensitive, .diacriticInsensitive]
        return term.range(of: needle, options: options) != nil || meaning.range(of: needle, options: options) != nil
    }
}
