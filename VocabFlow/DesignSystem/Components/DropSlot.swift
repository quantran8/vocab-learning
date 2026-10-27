import SwiftUI

struct DropSlot: View {
    let isTargeted: Bool
    let isFilled: Bool
    let sentence: String
    let sizingText: String
    @Environment(\.motion) private var motion

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: Radii.tile, style: .continuous)
        WordTile(text: sizingText, visualState: .idle)
            .fixedSize()
            .frame(minWidth: Spacing.slotMinWidth)
            .hidden()
            .overlay {
                ZStack {
                    shape.fill(isTargeted ? Color.selectedSurface : Color.slotSurface)
                    shape.strokeBorder(
                        isTargeted ? Color.slotTargetedStroke : Color.slotStroke,
                        style: StrokeStyle(lineWidth: 2, dash: isFilled ? [] : [7, 5])
                    )
                    Image(systemName: "plus")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(Color.slotStroke)
                        .opacity(isFilled ? 0 : 1)
                }
                .scaleEffect(isTargeted ? motion.pulseScale : 1)
                .animation(motion.animation(MotionTokens.lift), value: isTargeted)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text("Answer slot in: \(sentence)"))
            .accessibilityValue(isFilled ? Text("Filled") : Text("Empty"))
            .accessibilityHint(Text("Select a word tile, then check."))
    }
}
