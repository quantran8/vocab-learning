import SwiftUI

struct DraggableWordTile: View {
    let option: WordOption
    let visualState: WordTileVisualState
    let restingOffset: CGSize
    let dropFrame: CGRect
    var isPlaced = false
    let isInteractive: Bool
    let cancelToken: Int
    let onFrameChange: (CGRect) -> Void
    let onTap: () -> Void
    let onDragBegan: () -> Bool
    let onTargetChanged: (Bool) -> Void
    let onDragEnded: (_ droppedOnSlot: Bool) -> Animation?
    let onDragCancelled: () -> Void

    @Environment(\.motion) private var motion
    @GestureState private var isGestureActive = false
    @State private var translation: CGSize = .zero
    @State private var frame: CGRect = .zero
    @State private var isPressed = false
    @State private var isDragging = false
    @State private var isTargeting = false
    @State private var didEnd = false
    @State private var ignoresCurrentGesture = false

    var body: some View {
        WordTile(text: option.text, visualState: displayedState)
            .offset(
                x: restingOffset.width + translation.width,
                y: restingOffset.height + translation.height
            )
            // Measured outside the offset: this is the tile's home frame in the bank. Measuring inside
            // would include the drag translation, which the hit test then adds a second time.
            .background {
                Color.clear
                    .onGeometryChange(for: CGRect.self) { proxy in
                        proxy.frame(in: .named(BuildInteractionState.boardSpace))
                    } action: { newFrame in
                        frame = newFrame
                        onFrameChange(newFrame)
                    }
            }
            .zIndex(isDragging || restingOffset != .zero ? 1 : 0)
            .gesture(gesture, including: isInteractive ? .all : .none)
            .onChange(of: isGestureActive) { _, active in
                if active {
                    didEnd = false
                    ignoresCurrentGesture = false
                } else if !didEnd {
                    cancel(notify: true)
                }
            }
            .onChange(of: cancelToken) {
                cancel(notify: false)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text("\(option.text), option"))
            .accessibilityValue(accessibilityValue)
            .accessibilityAddTraits(visualState == .selected ? [.isButton, .isSelected] : .isButton)
            .accessibilityAction {
                if isInteractive { onTap() }
            }
    }

    private var displayedState: WordTileVisualState {
        guard isInteractive else { return visualState }
        if isDragging { return .dragging }
        if isPressed { return .pressed }
        return visualState
    }

    private var gesture: some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .named(BuildInteractionState.boardSpace))
            .updating($isGestureActive) { _, state, _ in state = true }
            .onChanged { value in
                guard !ignoresCurrentGesture else { return }
                let current = value.translation
                if isDragging {
                    translation = current
                    updateTarget(current)
                } else if hypot(current.width, current.height) >= BuildInteractionState.dragThreshold {
                    isPressed = false
                    guard onDragBegan() else {
                        ignoresCurrentGesture = true
                        return
                    }
                    isDragging = true
                    translation = current
                    updateTarget(current)
                } else if !isPressed {
                    isPressed = true
                }
            }
            .onEnded { value in
                didEnd = true
                isPressed = false
                guard !ignoresCurrentGesture else { return }
                if isDragging {
                    isDragging = false
                    let dropped = BuildInteractionState.isOver(dropFrame, tileFrame: frame, translation: displacement(value.translation))
                    isTargeting = false
                    let animation = onDragEnded(dropped)
                    withAnimation(animation) { translation = .zero }
                } else if hypot(value.translation.width, value.translation.height) < BuildInteractionState.dragThreshold {
                    onTap()
                }
            }
    }

    private func updateTarget(_ current: CGSize) {
        let hit = BuildInteractionState.isOver(dropFrame, tileFrame: frame, translation: displacement(current))
        if hit != isTargeting {
            isTargeting = hit
            onTargetChanged(hit)
        }
    }

    /// Where the tile is drawn relative to its layout frame (a placed tile starts on the slot).
    private func displacement(_ translation: CGSize) -> CGSize {
        CGSize(width: restingOffset.width + translation.width, height: restingOffset.height + translation.height)
    }

    private func cancel(notify: Bool) {
        isPressed = false
        if isGestureActive { ignoresCurrentGesture = true }
        guard isDragging || translation != .zero else { return }
        isDragging = false
        isTargeting = false
        withAnimation(motion.travel(MotionTokens.returnToOrigin)) { translation = .zero }
        if notify { onDragCancelled() }
    }

    private var accessibilityValue: Text {
        if isPlaced, visualState == .idle { return Text("In the answer slot") }
        return switch visualState {
        case .selected: Text("Selected")
        case .correct: Text("Correct, placed in the answer slot")
        case .incorrect: Text("Incorrect")
        case .disabled: Text("Unavailable")
        default: Text(verbatim: "")
        }
    }
}
