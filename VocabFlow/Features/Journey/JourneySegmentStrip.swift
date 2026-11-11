import SwiftUI

/// The Home card's map of the current segment: the Journey's own nodes (`JourneyNodeView`) on one straight track,
/// sessions left to right and the review last. Laid out at full size, then scaled down as a whole to fit the card,
/// so the current node and the review are always in view and the nodes look exactly as on the Journey.
struct JourneySegmentStrip: View {
    let segment: JourneySegment
    /// The current node starts its step; any other node opens the full Journey.
    let onStartCurrent: (JourneyNode) -> Void
    let onOpenJourney: () -> Void

    /// Space between neighbouring node faces, at full size.
    private static let gap: CGFloat = 18
    /// Room above for the current node's focus ring.
    private static let ringRoom: CGFloat = JourneyNodeView.ringGap + 2

    @State private var availableWidth: CGFloat = 0

    private var ordered: [JourneyNode] {
        segment.nodes.filter { $0.type == .learning } + segment.nodes.filter { $0.type == .review }
    }

    var body: some View {
        let layout = Layout(nodes: ordered)
        let scale = availableWidth > 0 ? min(1, availableWidth / layout.size.width) : 1
        Color.clear
            .frame(maxWidth: .infinity)
            .frame(height: layout.size.height * scale)
            .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { availableWidth = $0 }
            .overlay {
                map(layout)
                    .frame(width: layout.size.width, height: layout.size.height)
                    .scaleEffect(scale)
            }
            .accessibilityElement(children: .contain)
            .accessibilityLabel(Text("Segment \(segment.segmentNo)"))
    }

    private func map(_ layout: Layout) -> some View {
        let line = StrokeStyle(lineWidth: JourneySnakeLayout.trackWidth, lineCap: .round)
        return ZStack(alignment: .topLeading) {
            Group {
                layout.track(traveled: false).stroke(Color.stroke, style: line)
                layout.track(traveled: true).stroke(Color.success, style: line)
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)

            ForEach(Array(layout.nodes.enumerated()), id: \.element.id) { index, node in
                JourneyNodeView(node: node) {
                    node.state == .current ? onStartCurrent(node) : onOpenJourney()
                }
                // The face, not the frame (which includes the depth edge), sits on the track.
                .position(x: layout.xs[index], y: layout.lineY + Spacing.buttonDepth / 2)
            }
        }
    }

    /// Full-size geometry: node centres on one horizontal line.
    private struct Layout {
        let nodes: [JourneyNode]
        let xs: [CGFloat]
        let lineY: CGFloat
        let size: CGSize

        init(nodes: [JourneyNode]) {
            func width(_ node: JourneyNode) -> CGFloat {
                node.type == .review ? JourneyNodeView.reviewSize : JourneyNodeView.learningSize
            }
            var xs: [CGFloat] = []
            var x: CGFloat = 0
            for (index, node) in nodes.enumerated() {
                x += index == 0 ? width(node) / 2 : (width(nodes[index - 1]) + width(node)) / 2 + JourneySegmentStrip.gap
                xs.append(x)
            }
            let tallest = nodes.map(width).max() ?? JourneyNodeView.learningSize
            self.nodes = nodes
            self.xs = xs
            lineY = JourneySegmentStrip.ringRoom + tallest / 2
            size = CGSize(
                width: max(1, x + (nodes.last.map(width) ?? 0) / 2),
                height: JourneySegmentStrip.ringRoom + tallest + Spacing.buttonDepth + JourneySegmentStrip.ringRoom
            )
        }

        /// The whole line, or the stretches that lead into an unlocked node.
        func track(traveled: Bool) -> Path {
            var path = Path()
            for index in xs.indices.dropFirst() where !traveled || nodes[index].state != .locked {
                path.move(to: CGPoint(x: xs[index - 1], y: lineY))
                path.addLine(to: CGPoint(x: xs[index], y: lineY))
            }
            return path
        }
    }
}

#Preview {
    VStack(spacing: Spacing.xl) {
        ForEach(Journey.preview.segments) { segment in
            JourneySegmentStrip(segment: segment, onStartCurrent: { _ in }, onOpenJourney: {})
        }
    }
    .padding()
}
