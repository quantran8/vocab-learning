import SwiftUI

struct PrimaryButton: View {
    let title: LocalizedStringKey
    var systemImage: String? = "arrow.right"
    var requirement: LocalizedStringKey?
    var isEnabled = true
    let action: () -> Void

    var body: some View {
        VStack(spacing: Spacing.xs) {
            if !isEnabled, let requirement {
                Text(requirement)
                    .font(Typography.micro)
                    .foregroundStyle(Color.mutedInk)
                    .multilineTextAlignment(.center)
            }
            Button(action: action) {
                HStack(spacing: Spacing.xs) {
                    Text(title)
                    if let systemImage {
                        Image(systemName: systemImage)
                            .font(.subheadline.weight(.bold))
                            .accessibilityHidden(true)
                    }
                }
                .font(Typography.action)
                .frame(maxWidth: .infinity, minHeight: Spacing.minTouchTarget)
                .padding(.vertical, Spacing.xs)
            }
            .buttonStyle(ChunkyButtonStyle())
            .disabled(!isEnabled)
        }
    }
}

struct ChunkyButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.motion) private var motion

    func makeBody(configuration: Configuration) -> some View {
        let shape = RoundedRectangle(cornerRadius: Radii.primaryAction, style: .continuous)
        let pressed = configuration.isPressed && isEnabled
        configuration.label
            .foregroundStyle(Color.white)
            .background(isEnabled ? Color.primaryAction : Color.disabledFace, in: shape)
            .offset(y: pressed ? Spacing.buttonDepth - 1 : 0)
            .background(shape.fill(isEnabled ? Color.primaryDepth : Color.disabledDepth).offset(y: Spacing.buttonDepth))
            .padding(.bottom, Spacing.buttonDepth)
            .contentShape(shape)
            .animation(motion.animation(MotionTokens.press), value: pressed)
    }
}

struct PinnedActionBar<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        content
            .padding(.horizontal, Spacing.screenGutter)
            .padding(.top, Spacing.s)
            .padding(.bottom, Spacing.xs)
            .background(Color.canvas)
    }
}
