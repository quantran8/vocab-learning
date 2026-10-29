import SwiftUI

/// ✕ plus progress. `.segmented` shows one segment per step and a "1 / 5" count (word intro);
/// `.continuous` is a single bar (exercises).
struct FlowHeader: View {
    enum Style { case segmented, continuous }

    var style: Style = .continuous
    /// Accessibility name of the progress (e.g. "Learn", "Build").
    let stage: LocalizedStringKey
    let stageCurrent: Int
    let stageTotal: Int
    let step: Int
    let totalSteps: Int
    var closeLabel: LocalizedStringKey = "Exit flow"
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
            .accessibilityLabel(Text(closeLabel))

            Group {
                switch style {
                case .segmented: segmentedBar
                case .continuous: continuousBar
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(stage))
            .accessibilityValue(Text("Question \(stageCurrent) of \(stageTotal)"))

            if style == .segmented {
                Text(verbatim: "\(step) / \(totalSteps)")
                    .font(Typography.micro.weight(.bold).monospacedDigit())
                    .foregroundStyle(Color.mutedInk)
                    .accessibilityHidden(true)
            }
        }
    }

    private var segmentedBar: some View {
        HStack(spacing: Spacing.xxs) {
            ForEach(0..<max(totalSteps, 1), id: \.self) { index in
                Capsule()
                    .fill(index < step ? Color.interactive : Color.track)
                    .frame(height: 6)
            }
        }
        .animation(motion.animation(MotionTokens.progress), value: step)
    }

    private var continuousBar: some View {
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
    }

    private var fraction: CGFloat {
        totalSteps > 0 ? CGFloat(step) / CGFloat(totalSteps) : 0
    }
}
