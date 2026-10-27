import Foundation

enum AnswerEvaluator {
    static func normalize(_ text: String) -> String {
        text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .precomposedStringWithCanonicalMapping
            .lowercased()
    }

    static func isCorrect(tileID: String, for challenge: BuildChallenge) -> Bool {
        challenge.acceptedOptionIDs.contains(tileID)
    }

    static func isCorrect(typed text: String, for word: VocabularyItem) -> Bool {
        let input = normalize(text)
        guard !input.isEmpty else { return false }
        return word.allAcceptedForms.contains { normalize($0) == input }
    }
}
