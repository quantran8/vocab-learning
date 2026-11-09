import SwiftUI

/// One Journey node: a circle for a learning session, a larger rounded square for the review.
/// Colour follows type and state only (locked grey, current blue, done green, review done yellow),
/// always paired with a shape, a glyph and a spoken label so state never rests on colour alone.
struct JourneyNodeView: View {
    let node: JourneyNode
    let action: () -> Void

    static let learningSize: CGFloat = 64
    static let reviewSize: CGFloat = 88
    static let reviewRadius: CGFloat = 28
    /// Glyph sizes, scaled with the nodes.
    private static let learningGlyph: CGFloat = 28
    private static let reviewGlyph: CGFloat = 46
    /// Gap between the current node and its focus ring.
    static let ringGap: CGFloat = 6

    @Environment(\.motion) private var motion
    @State private var ringShown = false

    private var isReview: Bool { node.type == .review }
    private var size: CGFloat { isReview ? Self.reviewSize : Self.learningSize }

    var body: some View {
        Button(action: action) {
            glyph
                .frame(width: size, height: size)
        }
        .buttonStyle(JourneyNodeButtonStyle(isReview: isReview, palette: JourneyPalette(node: node)))
        .overlay(alignment: .top) {
            if node.state == .current {
                focusRing
            }
        }
        .animation(motion.animation(MotionTokens.feedback), value: node.state)
        .accessibilityLabel(Text(accessibilityLabel))
        .accessibilityHint(Text(accessibilityHint))
    }

    @ViewBuilder
    private var glyph: some View {
        let palette = JourneyPalette(node: node)
        let ink = palette.glyph
        switch (node.type, node.state) {
        case (.learning, .locked):
            // A locked review keeps its own mark (in the locked greys, below), so it still reads as the review.
            Image(systemName: "lock.fill")
                .font(.system(size: Self.learningGlyph - 2, weight: .bold))
                .foregroundStyle(ink)
        case (.review, .completed):
            // White on yellow is faint, so the glyph gets an ink keyline (the spec keeps it white).
            MemoryStackGlyph(cutout: .ink, keyline: .ink)
                .frame(width: Self.reviewGlyph, height: Self.reviewGlyph)
                .overlay(alignment: .bottomTrailing) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 21, weight: .black))
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(Color.white, Color.ink)
                        .offset(x: 9, y: 9)
                }
        case (.review, _):
            MemoryStackGlyph(fill: ink, cutout: palette.face)
                .frame(width: Self.reviewGlyph, height: Self.reviewGlyph)
        case (.learning, .completed):
            Image(systemName: "checkmark")
                .font(.system(size: Self.learningGlyph, weight: .black))
                .foregroundStyle(ink)
        case (.learning, .current):
            // A star, not a number: nothing restarts at 1 each segment.
            Image(systemName: "star.fill")
                .font(.system(size: Self.learningGlyph, weight: .black))
                .foregroundStyle(ink)
        }
    }

    /// Shown once as the node becomes current; it never pulses.
    private var focusRing: some View {
        let ringSize = size + Self.ringGap * 2
        return Group {
            if isReview {
                RoundedRectangle(cornerRadius: Self.reviewRadius + Self.ringGap, style: .continuous)
                    .strokeBorder(Color.focusRing.opacity(0.35), lineWidth: 3)
            } else {
                Circle().strokeBorder(Color.focusRing.opacity(0.35), lineWidth: 3)
            }
        }
        .frame(width: ringSize, height: ringSize + Spacing.buttonDepth)
        .offset(y: -Self.ringGap)
        .scaleEffect(ringShown || motion.reduceMotion ? 1 : 0.85)
        .opacity(ringShown ? 1 : 0)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .onAppear { motion.perform(MotionTokens.entrance) { ringShown = true } }
    }

    private var accessibilityLabel: String {
        let step = isReview
            ? String(localized: "Segment review", defaultValue: "Review", bundle: .appLanguage)
            : String(localized: "Session \(node.ordinal)", bundle: .appLanguage)
        let state = switch node.state {
        case .locked: String(localized: "locked", bundle: .appLanguage)
        case .current: String(localized: "ready", bundle: .appLanguage)
        case .completed: String(localized: "completed", bundle: .appLanguage)
        }
        return String(localized: "Segment \(node.segmentNo), \(step), \(state)", bundle: .appLanguage)
    }

    private var accessibilityHint: String {
        switch (node.type, node.state) {
        case (_, .current): String(localized: "Starts this step", bundle: .appLanguage)
        case (.review, .completed): String(localized: "Shows your review result", bundle: .appLanguage)
        case (_, .locked): String(localized: "Complete the previous step to unlock", bundle: .appLanguage)
        case (.learning, .completed): ""
        }
    }
}

/// Face, edge and glyph colours, all from existing tokens.
struct JourneyPalette {
    let face: Color
    let edge: Color
    let glyph: Color

    init(node: JourneyNode) {
        switch (node.type, node.state) {
        case (_, .locked):
            self.init(face: .disabledSurface, edge: .tileDepth, glyph: .disabledInk)
        case (_, .current):
            self.init(face: .interactive, edge: .interactiveDepth, glyph: .white)
        case (.learning, .completed):
            self.init(face: .success, edge: .successInk, glyph: .white)
        case (.review, .completed):
            self.init(face: .reward, edge: .rewardDepth, glyph: .white)
        }
    }

    private init(face: Color, edge: Color, glyph: Color) {
        self.face = face
        self.edge = edge
        self.glyph = glyph
    }
}

/// The game-like thick edge, allowed in the Journey only. It sinks into the edge while pressed.
private struct JourneyNodeButtonStyle: ButtonStyle {
    let isReview: Bool
    let palette: JourneyPalette
    @Environment(\.motion) private var motion

    func makeBody(configuration: Configuration) -> some View {
        let shape = isReview
            ? AnyShape(RoundedRectangle(cornerRadius: JourneyNodeView.reviewRadius, style: .continuous))
            : AnyShape(Circle())
        let depth = Spacing.buttonDepth
        let pressed = configuration.isPressed
        configuration.label
            .background(palette.face, in: shape)
            .offset(y: pressed ? depth - 1 : 0)
            .background(shape.fill(palette.edge).offset(y: depth))
            .padding(.bottom, depth)
            .contentShape(shape)
            .scaleEffect(pressed && !motion.reduceMotion ? MotionTokens.pressedScale : 1)
            .animation(motion.animation(MotionTokens.press), value: pressed)
    }
}

/// Two word cards stacked: the review's mark. White by default; `keyline` outlines it for light faces.
struct MemoryStackGlyph: View {
    var fill: Color = .white
    /// The word lines on the front card, normally the node face so they read as cut out.
    var cutout: Color
    var keyline: Color?

    var body: some View {
        Canvas { context, size in
            let unit = size.width / 36
            let card = CGSize(width: 24 * unit, height: 18 * unit)
            let radius = 4 * unit
            let back = Path(roundedRect: CGRect(origin: CGPoint(x: 10 * unit, y: 5 * unit), size: card), cornerRadius: radius)
            let front = Path(roundedRect: CGRect(origin: CGPoint(x: 3 * unit, y: 13 * unit), size: card), cornerRadius: radius)
            var lines = Path()
            lines.move(to: CGPoint(x: 8 * unit, y: 20 * unit))
            lines.addLine(to: CGPoint(x: 20 * unit, y: 20 * unit))
            lines.move(to: CGPoint(x: 8 * unit, y: 25.5 * unit))
            lines.addLine(to: CGPoint(x: 15 * unit, y: 25.5 * unit))
            let stroke = StrokeStyle(lineWidth: 3.25 * unit, lineCap: .round, lineJoin: .round)
            let outline = keyline ?? .clear
            // The back card is an outline, so the front one reads as lying on top of it.
            if keyline != nil {
                context.stroke(back, with: .color(outline), style: StrokeStyle(lineWidth: 6 * unit, lineJoin: .round))
            }
            context.stroke(back, with: .color(fill), style: stroke)
            if keyline != nil {
                context.stroke(front, with: .color(outline), style: StrokeStyle(lineWidth: 3 * unit))
            }
            context.fill(front, with: .color(fill))
            context.stroke(lines, with: .color(cutout), style: StrokeStyle(lineWidth: 2.5 * unit, lineCap: .round))
        }
        .accessibilityHidden(true)
    }
}

#Preview {
    let states: [(JourneyNode.Kind, JourneyNode.State)] = [
        (.learning, .locked), (.learning, .current), (.learning, .completed),
        (.review, .locked), (.review, .current), (.review, .completed),
    ]
    return VStack(spacing: Spacing.l) {
        ForEach(Array(states.enumerated()), id: \.offset) { index, item in
            JourneyNodeView(
                node: JourneyNode(id: "\(index)", segmentNo: 1, type: item.0, ordinal: 3, state: item.1,
                                  sessionId: nil, reviewId: nil, result: nil),
                action: {}
            )
        }
    }
    .padding()
}
