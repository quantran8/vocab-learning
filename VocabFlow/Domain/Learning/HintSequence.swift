import Foundation

enum HintSequence {
    static let maxHints = 2

    static func hint(for term: String, level: Int) -> String? {
        guard level > 0 else { return nil }
        let letters = Array(term)
        let revealed: Int
        switch level {
        case 1: revealed = 1
        default: revealed = max(1, (letters.count + 1) / 2)
        }
        return letters.enumerated()
            .map { index, letter in index < revealed ? String(letter) : "_" }
            .joined(separator: " ")
    }
}
