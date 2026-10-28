import CoreGraphics

enum TileInteractionPhase: Equatable {
    case idle
    case dragging(tileID: String)
    case settling(tileID: String)
    case evaluating
    case showingFeedback(isCorrect: Bool)
}

struct BuildInteractionState: Equatable {
    static let boardSpace = "buildBoard"
    static let dragThreshold: CGFloat = 4

    var phase: TileInteractionPhase = .idle
    var tileFrames: [String: CGRect] = [:]
    var slotFrame: CGRect = .zero
    /// The whole sentence panel is the drop target; a drop anywhere on it places the tile in the slot.
    var panelFrame: CGRect = .zero
    var isPanelTargeted = false
    var cancelToken = 0

    var draggingTileID: String? {
        if case .dragging(let id) = phase { return id }
        return nil
    }

    /// A placed tile keeps its layout spot in the bank and is drawn offset onto the slot.
    /// Top-aligned so the tile's depth stays above the slot's underline instead of covering it.
    func restingOffset(for tileID: String, placedTileID: String?) -> CGSize {
        guard placedTileID == tileID, let frame = tileFrames[tileID], !slotFrame.isEmpty else { return .zero }
        return CGSize(width: slotFrame.midX - frame.midX, height: slotFrame.minY - frame.minY)
    }

    static func isOver(_ target: CGRect, tileFrame: CGRect, translation: CGSize) -> Bool {
        guard !target.isEmpty, !tileFrame.isEmpty else { return false }
        let center = CGPoint(x: tileFrame.midX + translation.width, y: tileFrame.midY + translation.height)
        return target.insetBy(dx: -Spacing.dropHitInset, dy: -Spacing.dropHitInset).contains(center)
    }
}
