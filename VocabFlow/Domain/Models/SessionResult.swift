import Foundation

enum RecallOutcome: Equatable {
    case unaidedRecall
    case hintedRecall
    case recalledAfterRetry
    case notRecalled
}

struct WordResult: Equatable, Identifiable {
    let wordID: String
    let term: String
    let recognized: Bool
    let buildAttemptCount: Int
    let recallAttemptCount: Int
    let hintCount: Int
    let recallOutcome: RecallOutcome?

    var id: String { wordID }
    var needsReview: Bool { recallOutcome != .unaidedRecall }
}

struct SessionResult: Equatable {
    let words: [WordResult]

    var totalWords: Int { words.count }
    var recognizedCount: Int { words.filter(\.recognized).count }
    var unaidedCount: Int { count(.unaidedRecall) }
    var hintedCount: Int { count(.hintedRecall) }
    var afterRetryCount: Int { count(.recalledAfterRetry) }
    var notRecalledCount: Int { count(.notRecalled) }
    var totalAttempts: Int { words.reduce(0) { $0 + $1.buildAttemptCount + $1.recallAttemptCount } }
    var wordsToReview: [WordResult] { words.filter(\.needsReview) }

    private func count(_ outcome: RecallOutcome) -> Int {
        words.filter { $0.recallOutcome == outcome }.count
    }
}
