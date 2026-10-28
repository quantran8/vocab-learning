import SwiftUI

struct FlowHeader: View {
    /// Visible name of the current stage (e.g. "Meet the words", "Practice").
    let title: LocalizedStringKey
    let stage: LocalizedStringKey
    let stageCurrent: Int
    let stageTotal: Int
    let step: Int
    let totalSteps: Int
    let onClose: () -> Void
    @Environment(\.motion) private var motion

    var body: some View {
        HStack(spacing: Spacing.m) {
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 20, weight: .semibold))
                    .frame(width: Spacing.minTouchTarget, height: Spacing.minTouchTarget)
            }
            .foregroundStyle(Color.mutedInk)
            .padding(.leading, -Spacing.s)
            .accessibilityLabel(Text("Exit flow"))

            VStack(alignment: .leading, spacing: Spacing.xxs + 2) {
                Text(title)
                    .font(Typography.eyebrow)
                    .tracking(Typography.eyebrowTracking)
                    .textCase(.uppercase)
                    .foregroundStyle(Color.mutedInk)
                    .accessibilityAddTraits(.isHeader)
                progressBar
            }

            Text(verbatim: "\(step) / \(totalSteps)")
                .font(Typography.micro.weight(.bold).monospacedDigit())
                .foregroundStyle(Color.mutedInk)
                .accessibilityHidden(true)
        }
    }

    private var progressBar: some View {
        Capsule()
            .fill(Color.track)
            .frame(height: 8)
            .overlay(alignment: .leading) {
                GeometryReader { proxy in
                    Capsule()
                        .fill(Color.interactive)
                        .frame(width: proxy.size.width * fraction)
                }
            }
            .clipShape(Capsule())
            .animation(motion.animation(MotionTokens.progress), value: fraction)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(stage))
            .accessibilityValue(Text("Question \(stageCurrent) of \(stageTotal)"))
    }

    private var fraction: CGFloat {
        totalSteps > 0 ? CGFloat(step) / CGFloat(totalSteps) : 0
    }
}
