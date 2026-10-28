import SwiftUI

struct HintControl: View {
    let hintsUsed: Int
    let maxHints: Int
    let hints: [String]
    let isEnabled: Bool
    let onHint: () -> Void
    let onReveal: () -> Void
    @Environment(\.motion) private var motion

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack {
                Button(action: onHint) {
                    Label("Reveal a hint (\(hintsUsed)/\(maxHints))", systemImage: "lightbulb")
                        .frame(minHeight: Spacing.minTouchTarget)
                }
                .foregroundStyle(Color.selectedInk)
                .disabled(!isEnabled || hintsUsed >= maxHints)
                .opacity(isEnabled && hintsUsed < maxHints ? 1 : 0.4)

                Spacer()

                Button(action: onReveal) {
                    Text("Show answer")
                        .frame(minHeight: Spacing.minTouchTarget)
                }
                .foregroundStyle(Color.mutedInk)
                .disabled(!isEnabled)
                .opacity(isEnabled ? 1 : 0.4)
            }
            .font(Typography.secondary.weight(.bold))

            ForEach(Array(hints.enumerated()), id: \.offset) { _, hint in
                Text(verbatim: hint)
                    .font(.system(.subheadline, design: .monospaced, weight: .semibold))
                    .foregroundStyle(Color.selectedInk)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, Spacing.m)
                    .padding(.vertical, Spacing.s)
                    .background(Color.selectedSurface, in: RoundedRectangle(cornerRadius: Radii.chip, style: .continuous))
                    .accessibilityLabel(Text("Hint: \(hint.replacingOccurrences(of: "_", with: "blank"))"))
                    .transition(motion.popTransition)
            }
        }
        .animation(motion.animation(MotionTokens.feedback), value: hints)
    }
}
