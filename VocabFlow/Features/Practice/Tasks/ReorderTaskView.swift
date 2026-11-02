import SwiftUI

/// `flyReorder`: tap tiles onto the ruled answer lines, tap to send them back, drag to place or reorder.
/// Dragging uses a custom gesture (not the system drag session) so the row previews the drop slot live.
/// The row always comes from `attempt.placedTileIDs`, the state the backend will replay.
struct ReorderTaskView: View {
    let attempt: TaskAttempt
    @Environment(PracticeSessionStore.self) private var store
    @Environment(\.motion) private var motion
    @Namespace private var tileSpace

    @State private var dragID: Int?
    @State private var dragFromBank = false
    @State private var dragCenter: CGPoint = .zero
    @State private var grabOffset: CGSize = .zero
    @State private var insertIndex: Int?
    @State private var frames: [Int: CGRect] = [:]

    private static let tileSize: CGFloat = 54
    private static let tileSpacing = Spacing.xxs
    /// Keeps a tile's depth clear of the ruled line it sits above.
    private static let ruledLineGap = Spacing.xxs
    private static let ruledRowHeight = tileSize + Spacing.tileDepth + Spacing.xs + ruledLineGap
    private static let bankKeyOffset = 100_000
    private static let spaceName = "reorderSpace"

    var body: some View {
        TaskScaffold(attempt: attempt) {
            VStack(spacing: Spacing.l) {
                answerPanel
                    // Above the bank, so a tile leaving for the row isn't drawn under the gray slots.
                    .zIndex(1)

                FlowLayout(spacing: Self.tileSpacing, lineSpacing: Self.tileSpacing) {
                    // Every tile keeps its slot, so the bank doesn't reflow as tiles leave it.
                    // The gray slot sits under the tile rather than replacing it, so it stays until a returning tile lands.
                    ForEach(allTiles) { tile in
                        tileView(tile, isPlaced: false)
                            .hidden()
                            .background { slotPlaceholder(true) }
                            .accessibilityHidden(true)
                            .overlay {
                                if !attempt.placedTileIDs.contains(tile.id) {
                                    let isDragged = tile.id == dragID
                                    tileButton(tile, isPlaced: false)
                                        .opacity(isDragged ? 0 : 1)
                                        .reportFrame(key: tile.id + Self.bankKeyOffset)
                                        // While dragged, the real id lives in the answer row preview.
                                        .matchedGeometryEffect(id: isDragged ? tile.id + Self.bankKeyOffset : tile.id, in: tileSpace)
                                        .gesture(dragGesture(for: tile.id, fromBank: true) { animate { store.tapTile(tile.id) } })
                                }
                            }
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .coordinateSpace(name: Self.spaceName)
            .onPreferenceChange(TileFramesKey.self) { frames = $0 }
            .overlay(alignment: .topLeading) { floatingTile }
        } action: {
            VStack(spacing: 0) {
                if attempt.status == .answering {
                    HintControl(
                        hintsUsed: attempt.hintsUsed,
                        maxHints: TaskAttempt.maxHints,
                        hints: attempt.hints,
                        isEnabled: true,
                        canReveal: attempt.canReveal,
                        onHint: { store.useHint() },
                        onReveal: { store.reveal() }
                    )
                }
                TaskActionBar(attempt: attempt, canCheck: !attempt.placedTileIDs.isEmpty, onCheck: { store.submitTiles() }, showsReveal: false)
            }
        }
    }

    // MARK: Answer panel

    private static let panelKey = -1

    private var answerPanel: some View {
        let rowHeight = Self.ruledRowHeight
        return FlowLayout(spacing: Self.tileSpacing, lineSpacing: 0, alignment: .leading) {
            ForEach(panelTiles) { tile in
                tileButton(tile, isPlaced: true)
                    .opacity(tile.id == dragID ? 0 : 1)
                    .background { slotPlaceholder(tile.id == dragID) }
                    .reportFrame(key: tile.id)
                    .padding(.bottom, Self.ruledLineGap)
                    .frame(height: rowHeight, alignment: .bottom)
                    .matchedGeometryEffect(id: tile.id, in: tileSpace)
                    .gesture(dragGesture(for: tile.id, fromBank: false) { animate { store.removeTile(tile.id) } })
            }
        }
        .animation(motion.travel(MotionTokens.snap), value: panelTiles.map(\.id))
        .frame(maxWidth: .infinity, minHeight: rowHeight * CGFloat(minimumLines), alignment: .topLeading)
        .background(alignment: .top) { RuledLines(rowHeight: rowHeight, minimumLines: minimumLines) }
        .reportFrame(key: Self.panelKey)
    }

    /// In the backend's order, whichever side each tile is on.
    private var allTiles: [TaskOption] {
        guard case .reorder(let tiles, _) = attempt.task.body else { return [] }
        return tiles
    }

    /// A single word has no space tile and must always sit on one line.
    private var isSingleWord: Bool { !allTiles.contains { $0.text == " " } }

    private var minimumLines: Int { isSingleWord ? 1 : 2 }

    /// Tile width shrinks so every letter of a single word fits one line, in the row and in the bank.
    private var tileWidth: CGFloat {
        let full = Self.tileSize
        guard isSingleWord, let panel = frames[Self.panelKey]?.width, panel > 0 else { return full }
        let count = CGFloat(allTiles.count)
        let inner = panel
        let fitted = floor((inner - Self.tileSpacing * (count - 1)) / count) - 1
        return min(full, max(fitted, 20))
    }

    /// The row as it would look if dropped now: the dragged tile's slot is held open at the insert index.
    private var panelTiles: [TaskOption] {
        guard let dragID, let index = insertIndex,
              let dragged = (attempt.placedTiles + attempt.bankTiles).first(where: { $0.id == dragID })
        else { return attempt.placedTiles }
        var tiles = attempt.placedTiles.filter { $0.id != dragID }
        tiles.insert(dragged, at: min(index, tiles.count))
        return tiles
    }

    @ViewBuilder private var floatingTile: some View {
        if let dragID, let tile = (attempt.placedTiles + attempt.bankTiles).first(where: { $0.id == dragID }) {
            tileView(tile, isPlaced: !dragFromBank)
                .scaleEffect(motion.liftedScale)
                .shadow(color: .black.opacity(0.18), radius: 8, y: 4)
                .position(x: dragCenter.x, y: dragCenter.y)
                .allowsHitTesting(false)
        }
    }

    // MARK: Dragging

    /// One gesture for both intents, so a drag can never also fire a tap: a short touch is a tap, movement is a drag.
    private func dragGesture(for id: Int, fromBank: Bool, onTap: @escaping () -> Void) -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .named(Self.spaceName))
            .onChanged { value in
                guard attempt.status == .answering else { return }
                if dragID == nil {
                    guard hypot(value.translation.width, value.translation.height) >= 6 else { return }
                    let key = fromBank ? id + Self.bankKeyOffset : id
                    guard let frame = frames[key] else { return }
                    dragID = id
                    dragFromBank = fromBank
                    grabOffset = CGSize(width: frame.midX - value.startLocation.x, height: frame.midY - value.startLocation.y)
                    store.haptics.selectionChanged()
                }
                guard dragID == id else { return }
                dragCenter = CGPoint(x: value.location.x + grabOffset.width, y: value.location.y + grabOffset.height)
                let index = slotIndex(at: value.location)
                if index != insertIndex {
                    insertIndex = index
                    if index != nil { store.haptics.selectionChanged() }
                }
            }
            .onEnded { value in
                guard dragID == id else {
                    if dragID == nil, attempt.status == .answering,
                       hypot(value.translation.width, value.translation.height) < 10 { onTap() }
                    return
                }
                let target = insertIndex
                animate {
                    if let target { place(id, at: target) }
                    dragID = nil
                    insertIndex = nil
                }
            }
    }

    /// Where the row would insert a tile dropped at `point`, or nil when the point is outside the answer panel.
    private func slotIndex(at point: CGPoint) -> Int? {
        guard let panel = frames[Self.panelKey], panel.insetBy(dx: -Spacing.s, dy: -Spacing.s).contains(point) else { return nil }
        let rowHeight = Self.ruledRowHeight
        let others = attempt.placedTiles.filter { $0.id != dragID }
        return others.filter { tile in
            guard let frame = frames[tile.id] else { return false }
            if abs(frame.midY - point.y) < rowHeight / 2 { return frame.midX < point.x }
            return frame.midY < point.y
        }.count
    }

    /// Drops from the bank append first, then move; drops from the row only move.
    private func place(_ id: Int, at index: Int) {
        if attempt.bankTiles.contains(where: { $0.id == id }) {
            store.tapTile(id)
        }
        guard let current = store.currentAttempt?.placedTileIDs, current.contains(id) else { return }
        store.moveTile(id, to: min(index, current.count - 1))
    }

    private func animate(_ body: () -> Void) {
        withAnimation(motion.travel(MotionTokens.snap), body)
    }

    // MARK: Tiles

    /// Gray stand-in for a letter that left its slot: the drop preview in the row, the empty slot in the bank.
    @ViewBuilder private func slotPlaceholder(_ isActive: Bool) -> some View {
        if isActive {
            RoundedRectangle(cornerRadius: Radii.chip, style: .continuous)
                .fill(Color.stroke)
                .padding(.bottom, Spacing.tileDepth)
        }
    }

    private func tileButton(_ tile: TaskOption, isPlaced: Bool) -> some View {
        tileView(tile, isPlaced: isPlaced)
            .accessibilityElement(children: .ignore)
            .accessibilityAddTraits(.isButton)
            .accessibilityAction { animate { isPlaced ? store.removeTile(tile.id) : store.tapTile(tile.id) } }
            .accessibilityLabel(Text(verbatim: tile.text))
            .accessibilityHint(isPlaced ? Text("Removes the letter from your answer") : Text("Adds the letter to your answer"))
    }

    private func tileView(_ tile: TaskOption, isPlaced: Bool) -> some View {
        let shape = RoundedRectangle(cornerRadius: Radii.chip, style: .continuous)
        let isWrong = (attempt.status == .wrong || attempt.status == .exhausted) && isPlaced
        let isRight = attempt.status == .solved
        // A space is a real tile; show something that can be tapped.
        let label = tile.text == " " ? "␣" : tile.text
        return Text(verbatim: label)
            .font(.system(.title2, design: .monospaced, weight: .bold))
            .foregroundStyle(isRight ? Color.successInk : (isWrong ? Color.errorInk : Color.ink))
            .frame(minWidth: tileWidth, minHeight: Self.tileSize)
            .background(isRight ? Color.successSurface : (isWrong ? Color.errorSurface : Color.surface), in: shape)
            .overlay(shape.strokeBorder(isRight ? Color.success : (isWrong ? Color.error : Color.stroke), lineWidth: 1.5))
            .background(shape.fill(isRight ? Color.successDepth : (isWrong ? Color.errorDepth : Color.tileDepth)).offset(y: Spacing.tileDepth))
            .padding(.bottom, Spacing.tileDepth)
    }
}

private struct TileFramesKey: PreferenceKey {
    static let defaultValue: [Int: CGRect] = [:]
    static func reduce(value: inout [Int: CGRect], nextValue: () -> [Int: CGRect]) {
        value.merge(nextValue()) { _, new in new }
    }
}

private extension View {
    func reportFrame(key: Int) -> some View {
        background(GeometryReader { proxy in
            Color.clear.preference(key: TileFramesKey.self, value: [key: proxy.frame(in: .named("reorderSpace"))])
        })
    }
}

/// Notebook-style writing lines the answer tiles sit on. Grows with the panel, never fewer than `minimumLines`.
private struct RuledLines: View {
    let rowHeight: CGFloat
    let minimumLines: Int

    var body: some View {
        Canvas { context, size in
            let lines = max(minimumLines, Int((size.height / rowHeight).rounded()))
            for line in 1...lines {
                let y = rowHeight * CGFloat(line) - 1
                var path = Path()
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
                context.stroke(path, with: .color(Color.stroke), lineWidth: 1.5)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
