import SwiftUI

struct FlowHeader: View {
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

            Capsule()
                .fill(Color.track)
                .frame(height: 9)
                .overlay(alignment: .leading) {
                    GeometryReader { proxy in
                        Capsule()
                            .fill(Color.primaryAction)
                            .frame(width: proxy.size.width * fraction)
                    }
                }
                .clipShape(Capsule())
                .animation(motion.animation(MotionTokens.progress), value: fraction)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text(stage))
                .accessibilityValue(Text("Question \(stageCurrent) of \(stageTotal)"))

            Text(verbatim: "\(step) / \(totalSteps)")
                .font(Typography.micro.weight(.bold).monospacedDigit())
                .foregroundStyle(Color.mutedInk)
                .accessibilityHidden(true)
        }
    }

    private var fraction: CGFloat {
        totalSteps > 0 ? CGFloat(step) / CGFloat(totalSteps) : 0
    }
}
