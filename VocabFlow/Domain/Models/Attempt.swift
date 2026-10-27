import Foundation

enum AttemptStage: Equatable {
    case build
    case recall
}

struct Attempt: Equatable {
    let stage: AttemptStage
    let wordID: String
    let challengeID: String
    let submission: String
    let isCorrect: Bool
    let hintsUsed: Int
}
