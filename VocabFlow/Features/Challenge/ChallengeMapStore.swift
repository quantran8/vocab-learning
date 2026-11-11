import Foundation
import Observation

/// The server's Challenge Map. Refreshed when the shell appears (so after every Daily lesson too), after every
/// committed run and on pull-to-refresh. What's on screen is only a cache: nothing unlocks from it.
@Observable
@MainActor
final class ChallengeMapStore {
    private(set) var map: ChallengeMap?
    /// Set when the map couldn't load; whatever was on screen stays.
    private(set) var error: String?
    private(set) var isLoading = false
    /// Nodes the last refresh opened that weren't open before: they animate in once.
    private(set) var newlyUnlocked: Set<ChallengeNodeRef> = []

    private let api: VocabAPI
    /// Bumped by `reset`, so an answer for the previous account is dropped.
    private var generation = 0

    init(api: VocabAPI) {
        self.api = api
    }

    var summary: ChallengeHomeSummary? { map.flatMap(ChallengeHomeSummary.init(map:)) }

    func chapter(_ chapterNo: Int) -> ChallengeChapter? {
        map?.chapters.first { $0.chapterNo == chapterNo }
    }

    func level(_ node: ChallengeNodeRef) -> ChallengeLevel? {
        chapter(node.chapterNo)?.levels.first { $0.levelNo == node.levelNo }
    }

    func refresh() async {
        let started = generation
        isLoading = true
        defer { if started == generation { isLoading = false } }
        do {
            let fresh = try await api.challengeMap()
            guard started == generation else { return }
            if let old = map {
                newlyUnlocked = Self.playableNodes(fresh).subtracting(Self.playableNodes(old))
            }
            map = fresh
            error = nil
        } catch {
            guard started == generation, !Task.isCancelled else { return }
            self.error = error.asAPIError.userMessage
        }
    }

    /// Called once the unlock animation has played.
    func consumeUnlock(_ node: ChallengeNodeRef) {
        newlyUnlocked.remove(node)
    }

    func reset() {
        generation += 1
        map = nil
        error = nil
        isLoading = false
        newlyUnlocked = []
    }

    private static func playableNodes(_ map: ChallengeMap) -> Set<ChallengeNodeRef> {
        Set(map.chapters.flatMap { chapter in
            chapter.levels.filter(\.isPlayable).map { ChallengeNodeRef(chapterNo: chapter.chapterNo, levelNo: $0.levelNo) }
        })
    }
}
