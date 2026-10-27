import Foundation

struct WordOption: Codable, Identifiable, Equatable {
    let id: String
    let text: String
}

struct BuildChallenge: Codable, Identifiable, Equatable {
    static let blank = "___"

    let id: String
    let wordID: String
    let context: String
    let prompt: String
    var options: [WordOption]
    let acceptedOptionIDs: [String]
    let explanations: [String: String]

    func option(id: String) -> WordOption? {
        options.first { $0.id == id }
    }

    func filledPrompt(with text: String) -> String {
        prompt.replacingOccurrences(of: Self.blank, with: text)
    }
}
