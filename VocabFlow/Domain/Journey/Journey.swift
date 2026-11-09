import Foundation

/// `GET me/journey`: segments of seven learning sessions plus one review (the checkpoint challenge).
/// The backend decides every node state; the client only draws it.
struct Journey: Decodable, Equatable {
    let currentSegmentNo: Int
    let focusNodeId: String
    let completedReviewCount: Int
    /// Newest first: future previews, the current segment, then history.
    var segments: [JourneySegment]
    var hasMoreHistory: Bool
    var nextHistoryCursor: Int?

    var currentSegment: JourneySegment? { segments.first { $0.segmentNo == currentSegmentNo } }

    var focusNode: JourneyNode? {
        segments.lazy.flatMap(\.nodes).first { $0.id == focusNodeId }
    }

    /// Nodes for the Home preview, oldest first: `behind` nodes before the current one, then it and the next ones,
    /// `count` in all. Crosses segment boundaries, so just after a review it shows that (completed) review too.
    func nodesAroundFocus(count: Int = 4, behind: Int = 1) -> [JourneyNode] {
        let all = segments.sorted { $0.segmentNo < $1.segmentNo }.flatMap(\.nodes)
        guard let focus = all.firstIndex(where: { $0.id == focusNodeId }) else { return Array(all.prefix(count)) }
        let start = max(0, min(focus - behind, all.count - count))
        return Array(all[start..<min(all.count, start + count)])
    }

    /// Adds an older history page below, skipping segments already shown.
    func appendingHistory(_ page: Journey) -> Journey {
        let known = Set(segments.map(\.segmentNo))
        var merged = self
        merged.segments += page.segments.filter { !known.contains($0.segmentNo) }
        merged.hasMoreHistory = page.hasMoreHistory
        merged.nextHistoryCursor = page.nextHistoryCursor
        return merged
    }
}

struct JourneySegment: Decodable, Equatable, Identifiable {
    enum Status: String, Decodable {
        case completed, active, preview
    }

    let segmentNo: Int
    let status: Status
    let completedLearningCount: Int
    /// The learning nodes, then the review (ordinal = session count + 1). The session count is the learner's
    /// weekly goal, so segments can differ in length.
    let nodes: [JourneyNode]

    var id: Int { segmentNo }
    var sessionCount: Int { nodes.filter { $0.type == .learning }.count }
}

struct JourneyNode: Decodable, Equatable, Identifiable {
    enum Kind: String, Decodable {
        case learning, review
    }

    enum State: String, Decodable {
        case locked, current, completed
    }

    /// Stable across state changes ("segment:4:learning:3"), so a node animates in place instead of being replaced.
    let id: String
    let segmentNo: Int
    let type: Kind
    let ordinal: Int
    let state: State
    let sessionId: String?
    /// The checkpoint challenge id, once the review has opened.
    let reviewId: String?
    let result: ReviewResult?
}

/// Recall counts of one review. No pass mark: finishing the review completes it.
struct ReviewResult: Decodable, Equatable {
    let reviewedCount: Int
    let unaidedRecalledCount: Int
    let needsReviewCount: Int
}

/// Horizontal placement of Journey nodes along an imagined S curve; nothing is drawn between them.
enum JourneyLayout {
    /// Index stride per segment: the largest segment (7 sessions + review), so a node keeps its place on the
    /// curve whatever the learner's weekly goal.
    static let maxNodesPerSegment = 8
    static let maxOffset: Double = 66
    /// Vertical distance between node centres.
    static let pitch: Double = 108

    /// Continuous over the whole Journey (it never restarts at a segment), clamped to `limit`.
    static func offset(segmentNo: Int, ordinal: Int, limit: Double = maxOffset) -> Double {
        let index = Double((segmentNo - 1) * maxNodesPerSegment + ordinal - 1)
        let raw = 54 * sin(index * 0.70) + 12 * sin(index * 0.27)
        let bound = min(maxOffset, max(0, limit))
        return min(bound, max(-bound, raw * bound / maxOffset))
    }
}

extension JourneySegment {
    /// All locked, while the Journey loads: a placeholder never guesses a completed state.
    /// `sessions` is the learner's weekly goal (`LearnHome.checkpointSessionsRequired`) when known.
    static func placeholder(_ segmentNo: Int = 1, sessions: Int = 7) -> JourneySegment {
        let size = max(1, sessions)
        let nodes = (1...size + 1).map { ordinal in
            let isReview = ordinal == size + 1
            return JourneyNode(id: "segment:\(segmentNo):\(isReview ? "review" : "learning:\(ordinal)")", segmentNo: segmentNo,
                               type: isReview ? .review : .learning, ordinal: ordinal, state: .locked,
                               sessionId: nil, reviewId: nil, result: nil)
        }
        return JourneySegment(segmentNo: segmentNo, status: .preview, completedLearningCount: 0, nodes: nodes)
    }
}

extension Journey {
    /// Segment 1 reviewed, segment 2 on its fourth session. For previews and the offline API.
    static var preview: Journey {
        func segment(_ number: Int, status: JourneySegment.Status, done: Int, current: Bool) -> JourneySegment {
            let learning = (1...7).map { slot in
                JourneyNode(
                    id: "segment:\(number):learning:\(slot)", segmentNo: number, type: .learning, ordinal: slot,
                    state: slot <= done ? .completed : (current && slot == done + 1 ? .current : .locked),
                    sessionId: nil, reviewId: nil, result: nil
                )
            }
            let review = JourneyNode(
                id: "segment:\(number):review", segmentNo: number, type: .review, ordinal: 8,
                state: done == 7 ? .completed : .locked, sessionId: nil, reviewId: nil,
                result: done == 7 ? ReviewResult(reviewedCount: 21, unaidedRecalledCount: 14, needsReviewCount: 7) : nil
            )
            return JourneySegment(segmentNo: number, status: status, completedLearningCount: done, nodes: learning + [review])
        }
        return Journey(
            currentSegmentNo: 2,
            focusNodeId: "segment:2:learning:4",
            completedReviewCount: 1,
            segments: [
                segment(3, status: .preview, done: 0, current: false),
                segment(2, status: .active, done: 3, current: true),
                segment(1, status: .completed, done: 7, current: false),
            ],
            hasMoreHistory: false,
            nextHistoryCursor: nil
        )
    }
}
