import SwiftUI

/// The blank in a sentence: an underline sized to the longest option, so placing a tile never reflows the line.
struct DropSlot: View {
    let isTargeted: Bool
    let isFilled: Bool
    let sentence: String
    let sizingText: String
    @Environment(\.motion) private var motion

    var body: some View {
        WordTile(text: sizingText, visualState: .idle)
            .fixedSize()
            .frame(minWidth: Spacing.slotMinWidth)
            .hidden()
            // The tile (including its stepped depth) fills the area above; the underline sits in this gap.
            .padding(.bottom, Spacing.xs)
            .overlay(alignment: .bottom) {
                Capsule()
                    .fill(isTargeted ? Color.interactive : Color.ink)
                    .frame(height: 3)
                    .animation(motion.animation(MotionTokens.lift), value: isTargeted)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text("Answer slot in: \(sentence)"))
            .accessibilityValue(isFilled ? Text("Filled") : Text("Empty"))
            .accessibilityHint(Text("Tap a word tile to place it here, then check."))
    }
}
