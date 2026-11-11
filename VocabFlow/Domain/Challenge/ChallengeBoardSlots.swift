import Foundation

/// Where each tile sits on screen. The engine's column order is the replay rule; the screen keeps tiles in place
/// instead — xem memory match-madness-stable-slots.
enum ChallengeBoardSlots {
    /// A tile still on the board keeps its slot; a new tile takes a freed slot, top first. A slot with nothing left
    /// to fill stays empty (nil) so the tiles below don't move. `holding` tiles (just matched, still showing) keep
    /// their slot too; new tiles that find no free slot wait until they are released.
    static func reconcile(_ slots: [String?], with order: [String], holding: Set<String> = []) -> [String?] {
        let onBoard = Set(order)
        let stays = onBoard.union(holding)
        guard slots.contains(where: { $0.map(onBoard.contains) ?? false }) else { return order }

        let kept = Set(slots.compactMap { $0 })
        var incoming = order.filter { !kept.contains($0) }[...]
        var next = slots.map { slot -> String? in
            if let slot, stays.contains(slot) { return slot }
            return incoming.popFirst()
        }
        if !next.contains(where: { $0.map(holding.contains) ?? false }) {
            next.append(contentsOf: incoming.map(Optional.some))
        }
        return next
    }
}
