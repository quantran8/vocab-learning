import SwiftUI

/// The full Journey as one snake path, oldest at the bottom: rows of three nodes that alternate direction,
/// joined at the edge by a U-turn of track with no node on it. The snake runs on across segments with no gap: each
/// segment starts in the slot after the previous one's review, wherever that falls. Slots are counted from the
/// anchor segment (the current one), so loading older history below never moves the nodes above it.
/// Pure geometry: the view only positions nodes and labels at these points and strokes `track`.
struct JourneySnakeLayout {
    struct PlacedNode: Identifiable {
        let node: JourneyNode
        let center: CGPoint
        var id: String { node.id }
    }

    struct PlacedLabel: Identifiable {
        let segment: JourneySegment
        let center: CGPoint
        var id: Int { segment.segmentNo }
    }

    /// Vertical distance between rows, with room for a segment label in the gap.
    static let pitch: CGFloat = 136
    /// Keeps the snake compact on wide screens (iPad, landscape).
    static let maxHalfWidth: CGFloat = 180
    /// How far a U-turn swings out past the end nodes of the rows (more than half the review, so it shows).
    static let turnBulge: CGFloat = 44
    static let trackWidth: CGFloat = 10
    static let topInset: CGFloat = 64
    static let bottomInset: CGFloat = 32

    /// Oldest first, in path order.
    let nodes: [PlacedNode]
    let labels: [PlacedLabel]
    let size: CGSize

    /// `segments` in any order; `anchorSegmentNo` (normally `Journey.currentSegmentNo`) starts at slot 0, the
    /// oldest segment does when it's nil or missing. `width` is the content width the map may use.
    init(segments: [JourneySegment], anchorSegmentNo: Int?, width: CGFloat) {
        let half = min(Self.maxHalfWidth, max(0, width / 2))
        let rowX = max(0, half - Self.turnBulge - Self.trackWidth / 2)

        let ordered = segments.sorted { $0.segmentNo < $1.segmentNo }.filter { !$0.nodes.isEmpty }
        let anchor = ordered.firstIndex { $0.segmentNo == anchorSegmentNo } ?? 0
        var slot = -ordered[..<anchor].reduce(0) { $0 + $1.nodes.count }

        // Levels count rows upward.
        var levelled: [(node: JourneyNode, x: CGFloat, level: Double)] = []
        var labelLevels: [(segment: JourneySegment, level: Double)] = []
        for segment in ordered {
            let first = Self.slot(slot)
            // In the centre of the gap below the segment's first row; only the U-turns pass there, at the edges.
            labelLevels.append((segment, first.level - 0.5))
            for node in segment.nodes {
                let place = Self.slot(slot)
                levelled.append((node, CGFloat(place.column) * rowX, place.level))
                slot += 1
            }
        }

        let maxLevel = levelled.map(\.level).max() ?? 0
        let minLevel = min(levelled.map(\.level).min() ?? 0, labelLevels.map(\.level).min() ?? 0)
        let midX = max(width, 0) / 2
        func y(_ level: Double) -> CGFloat { Self.topInset + CGFloat(maxLevel - level) * Self.pitch }

        nodes = levelled.map { PlacedNode(node: $0.node, center: CGPoint(x: midX + $0.x, y: y($0.level))) }
        labels = labelLevels.map { PlacedLabel(segment: $0.segment, center: CGPoint(x: midX, y: y($0.level))) }
        size = CGSize(
            width: max(width, 0),
            height: levelled.isEmpty ? 0 : Self.topInset + CGFloat(maxLevel - minLevel) * Self.pitch + Self.bottomInset
        )
    }

    /// Slot `index` of the repeating pattern (negative below the anchor segment).
    /// `column` is -1 (left), 0 or 1 (right); even rows run left to right, odd rows back.
    static func slot(_ index: Int) -> (column: Int, level: Double) {
        let row = Int((Double(index) / 3).rounded(.down))
        let step = index - row * 3
        return (row.isMultiple(of: 2) ? step - 1 : 1 - step, Double(row))
    }

    /// The whole route (`traveled == false`), or only the stretches that lead into an unlocked node.
    func track(traveled: Bool) -> Path {
        var path = Path()
        for (from, to) in zip(nodes, nodes.dropFirst()) where !traveled || to.node.state != .locked {
            path.move(to: from.center)
            Self.connect(&path, from: from.center, to: to.center, midX: size.width / 2, bulge: Self.turnBulge)
        }
        return path
    }

    /// Straight along a row; between rows, a U-turn swinging `bulge` out past the end nodes.
    private static func connect(_ path: inout Path, from a: CGPoint, to b: CGPoint, midX: CGFloat, bulge: CGFloat) {
        let dx = b.x - a.x, dy = b.y - a.y
        if abs(dy) <= 0.5 {
            path.addLine(to: b)
            return
        }
        if abs(dx) <= 0.5 {
            let side = a.x - midX
            guard abs(side) > 0.5 else {
                path.addLine(to: b)
                return
            }
            let outer = a.x + (side > 0 ? bulge : -bulge)
            let radius = min(bulge, abs(dy) / 2)
            path.addArc(tangent1End: CGPoint(x: outer, y: a.y), tangent2End: CGPoint(x: outer, y: b.y), radius: radius)
            path.addArc(tangent1End: CGPoint(x: outer, y: b.y), tangent2End: b, radius: radius)
            path.addLine(to: b)
            return
        }
        // Not produced by the snake's own slots; a single rounded corner on the outer node's side.
        let verticalFirst = abs(a.x - midX) >= abs(b.x - midX)
        let corner = verticalFirst ? CGPoint(x: a.x, y: b.y) : CGPoint(x: b.x, y: a.y)
        path.addArc(tangent1End: corner, tangent2End: b, radius: min(abs(dx), abs(dy)))
        path.addLine(to: b)
    }
}

/// The grey route with the travelled stretch in green on top. Decoration only.
struct JourneySnakeTrack: View {
    let layout: JourneySnakeLayout
    @Environment(\.motion) private var motion

    var body: some View {
        let line = StrokeStyle(lineWidth: JourneySnakeLayout.trackWidth, lineCap: .round, lineJoin: .round)
        ZStack {
            layout.track(traveled: false).stroke(Color.stroke, style: line)
            layout.track(traveled: true).stroke(Color.success, style: line)
        }
        .frame(width: layout.size.width, height: layout.size.height)
        .animation(motion.animation(MotionTokens.feedback), value: layout.nodes.map(\.node.state))
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// The "Segment N" capsule placed on the snake.
struct JourneySegmentLabel: View {
    let segment: JourneySegment

    var body: some View {
        Text("Segment \(segment.segmentNo)")
            .font(Typography.eyebrow)
            .tracking(Typography.eyebrowTracking)
            .textCase(.uppercase)
            .foregroundStyle(segment.status == .active ? Color.ink : Color.mutedInk)
            .padding(.horizontal, Spacing.s)
            .padding(.vertical, Spacing.xxs + 2)
            .background(Color.quietSurface, in: Capsule())
            .overlay(Capsule().strokeBorder(Color.stroke, lineWidth: 1))
            .fixedSize()
            .accessibilityAddTraits(.isHeader)
    }
}
