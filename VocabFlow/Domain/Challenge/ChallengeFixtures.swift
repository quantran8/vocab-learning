import Foundation

// Static maps for previews and `OfflineVocabAPI`. Never used to decide anything for a signed-in learner.

extension ChallengeLevel {
    static func preview(_ levelNo: Int, state: State, bestStars: Int = 0) -> ChallengeLevel {
        ChallengeLevel(levelNo: levelNo, state: state, bestStars: bestStars, bestScore: bestStars > 0 ? 1_200 + bestStars * 300 : 0)
    }
}

extension ChallengeMap {
    static let preview = ChallengeMap(
        chapters: [
            ChallengeChapter(
                id: "preview-1",
                chapterNo: 1,
                state: .completed,
                explanationLocale: "vi-VN",
                starsEarned: 7,
                maxStars: 9,
                levels: [.preview(1, state: .cleared, bestStars: 3), .preview(2, state: .cleared, bestStars: 2), .preview(3, state: .cleared, bestStars: 2)]
            ),
            ChallengeChapter(
                id: "preview-2",
                chapterNo: 2,
                state: .active,
                explanationLocale: "vi-VN",
                starsEarned: 1,
                maxStars: 9,
                levels: [.preview(1, state: .cleared, bestStars: 1), .preview(2, state: .available), .preview(3, state: .locked)]
            ),
        ],
        nextChapter: ChallengeChapterPreview(chapterNo: 3, state: .locked, eligibleNewCount: 5, requiredNewCount: 12),
        currentNode: ChallengeNodeRef(chapterNo: 2, levelNo: 2)
    )

    static let previewNotEligible = ChallengeMap(
        chapters: [],
        nextChapter: ChallengeChapterPreview(chapterNo: 1, state: .needsVocabulary, eligibleNewCount: 7, requiredNewCount: 12),
        currentNode: nil
    )
}
