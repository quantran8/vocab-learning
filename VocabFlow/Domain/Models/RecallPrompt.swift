import Foundation

struct RecallPrompt: Codable, Identifiable, Equatable {
    let id: String
    let wordID: String
    let sentence: String
}
