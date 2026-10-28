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

struct SecondaryButton: View {
    let title: LocalizedStringKey
    var systemImage: String?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.xs) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.subheadline.weight(.bold))
                        .accessibilityHidden(true)
                }
                Text(title)
            }
            .font(Typography.action)
            .frame(maxWidth: .infinity, minHeight: Spacing.minTouchTarget)
            .padding(.vertical, Spacing.xxs)
        }
        .buttonStyle(ChunkyButtonStyle(kind: .secondary))
    }
}

struct ChunkyButtonStyle: ButtonStyle {
    enum Kind { case primary, secondary }

    var kind: Kind = .primary
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.motion) private var motion

    func makeBody(configuration: Configuration) -> some View {
        let shape = RoundedRectangle(cornerRadius: Radii.primaryAction, style: .continuous)
        let pressed = configuration.isPressed && isEnabled
        let depth = kind == .primary ? Spacing.buttonDepth : Spacing.buttonDepth - 1
        configuration.label
            .foregroundStyle(foreground)
            .background(face, in: shape)
            .overlay(shape.strokeBorder(kind == .secondary ? Color.stroke : .clear, lineWidth: 1.5))
            .offset(y: pressed ? depth - 1 : 0)
            .background(shape.fill(isEnabled ? depthColor : .clear).offset(y: depth))
            .padding(.bottom, depth)
            .contentShape(shape)
            .animation(motion.animation(MotionTokens.press), value: pressed)
    }

    private var foreground: Color {
        guard isEnabled else { return .disabledInk }
        return kind == .primary ? .white : .ink
    }

    private var face: Color {
        guard isEnabled else { return .disabledSurface }
        return kind == .primary ? .primaryAction : .surface
    }

    private var depthColor: Color {
        kind == .primary ? .primaryDepth : .tileDepth
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
