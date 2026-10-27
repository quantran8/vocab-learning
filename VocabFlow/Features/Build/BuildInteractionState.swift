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
    var selectedTileID: String?
    var placedTileID: String?
    var tileFrames: [String: CGRect] = [:]
    var slotFrame: CGRect = .zero
    var isSlotTargeted = false
    var cancelToken = 0

    var draggingTileID: String? {
        if case .dragging(let id) = phase { return id }
        return nil
    }

    func restingOffset(for tileID: String) -> CGSize {
        guard placedTileID == tileID, let frame = tileFrames[tileID], !slotFrame.isEmpty else { return .zero }
        return CGSize(width: slotFrame.midX - frame.midX, height: slotFrame.midY - frame.midY)
    }

    static func isOver(slot: CGRect, tileFrame: CGRect, translation: CGSize) -> Bool {
        guard !slot.isEmpty, !tileFrame.isEmpty else { return false }
        let center = CGPoint(x: tileFrame.midX + translation.width, y: tileFrame.midY + translation.height)
        return slot.insetBy(dx: -Spacing.dropHitInset, dy: -Spacing.dropHitInset).contains(center)
    }
}
