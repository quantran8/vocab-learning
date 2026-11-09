import SwiftUI

/// The Home card's short map: a few nodes around the current one (`Journey.nodesAroundFocus`), oldest at the
/// bottom, swinging on the Journey's S curve. It may cross into the previous segment; the full Journey shows the rest.
struct JourneyMapPreview: View {
    /// Oldest first.
    let nodes: [JourneyNode]
    /// The current node starts its step; any other node opens the full Journey.
    let onStartCurrent: (JourneyNode) -> Void
    let onOpenJourney: () -> Void

    /// Tighter than the Journey's `JourneyLayout.pitch` so four nodes stay around 300–330pt:
    /// neighbours sit on different sides, so they don't touch.
    private static let learningPitch: CGFloat = 76
    private static let reviewPitch: CGFloat = 100
    /// Fits the card on the narrowest phone (the review square stays inside the card's padding).
    private static let swing: Double = 56

    var body: some View {
        VStack(spacing: 0) {
            ForEach(nodes.reversed()) { node in
                JourneyNodeView(node: node) {
                    node.state == .current ? onStartCurrent(node) : onOpenJourney()
                }
                .offset(x: JourneyLayout.offset(segmentNo: node.segmentNo, ordinal: node.ordinal, limit: Self.swing))
                .frame(maxWidth: .infinity, minHeight: node.type == .review ? Self.reviewPitch : Self.learningPitch)
            }
        }
        .padding(.vertical, JourneyNodeView.ringGap)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text("Segment \(segmentNo)"))
    }

    private var segmentNo: Int {
        (nodes.first { $0.state == .current } ?? nodes.first)?.segmentNo ?? 1
    }
}

#Preview {
    JourneyMapPreview(nodes: Journey.preview.nodesAroundFocus(), onStartCurrent: { _ in }, onOpenJourney: {})
        .padding()
}
