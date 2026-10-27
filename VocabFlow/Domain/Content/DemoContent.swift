import Foundation

struct DemoContent: Codable, Equatable {
    var seed: UInt64?
    var words: [VocabularyItem]
    var buildChallenges: [BuildChallenge]
    var recallPrompts: [RecallPrompt]

    func word(id: String) -> VocabularyItem? {
        words.first { $0.id == id }
    }

    func withShuffledOptions(seed: UInt64) -> DemoContent {
        var copy = self
        copy.buildChallenges = buildChallenges.enumerated().map { index, challenge in
            var shuffled = challenge
            shuffled.options = DemoSeed.shuffled(challenge.options, seed: seed &+ UInt64(index))
            return shuffled
        }
        return copy
    }
}
