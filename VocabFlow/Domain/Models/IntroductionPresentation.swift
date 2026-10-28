import Foundation

/// The six word-only introduction motion recipes. Presentation only: never scored.
enum IntroductionTemplateID: String, Codable, CaseIterable, Identifiable {
    case letterCascade, wordAssemble, letterWave, swipeReveal, flipLetters, chunkMerge

    var id: String { rawValue }
}

struct IntroductionPresentation: Codable, Equatable {
    let templateID: IntroductionTemplateID
    /// Curated orthographic groups for `chunkMerge` only — visual spelling chunks, not syllables.
    var introChunks: [String]?

    static let fallbackTemplate: IntroductionTemplateID = .swipeReveal

    /// Chunks must be nonempty and concatenate exactly to the displayed spelling.
    static func areValidChunks(_ chunks: [String]?, for word: String) -> Bool {
        guard let chunks, !chunks.isEmpty, chunks.allSatisfy({ !$0.isEmpty }) else { return false }
        return chunks.joined() == word
    }

    /// The presentation actually rendered. Chunk Merge with missing or malformed chunks
    /// falls back to Swipe Reveal so the word is still introduced in full.
    func resolved(for word: String) -> IntroductionPresentation {
        guard templateID == .chunkMerge, !Self.areValidChunks(introChunks, for: word) else { return self }
        return IntroductionPresentation(templateID: Self.fallbackTemplate, introChunks: nil)
    }

    /// Same word, another recipe (demo motion selector). Keeps the curated chunks.
    func switched(to templateID: IntroductionTemplateID, for word: String) -> IntroductionPresentation {
        IntroductionPresentation(templateID: templateID, introChunks: introChunks).resolved(for: word)
    }
}
