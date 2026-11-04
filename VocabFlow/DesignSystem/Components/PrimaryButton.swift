import SwiftUI

struct PrimaryButton: View {
    let title: LocalizedStringKey
    var systemImage: String?
    var requirement: LocalizedStringKey?
    var isEnabled = true
    var shimmers = false
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
                .padding(.vertical, Spacing.xxs)
            }
            .buttonStyle(ActionButtonStyle(shimmers: shimmers))
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
        .buttonStyle(ActionButtonStyle(kind: .secondary))
    }
}

struct DestructiveButton: View {
    let title: LocalizedStringKey
    var systemImage: String?
    var isLoading = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.xs) {
                if isLoading {
                    ProgressView()
                } else if let systemImage {
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
        .buttonStyle(ActionButtonStyle(kind: .destructive))
    }
}

/// Lesson zone: a thick edge the face sinks into. Product zone: flat, and shrinks slightly when pressed.
struct ActionButtonStyle: ButtonStyle {
    enum Kind { case primary, secondary, destructive }

    var kind: Kind = .primary
    var shimmers = false
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.motion) private var motion
    @Environment(\.designZone) private var zone

    func makeBody(configuration: Configuration) -> some View {
        let shape = RoundedRectangle(cornerRadius: Radii.primaryAction, style: .continuous)
        let pressed = configuration.isPressed && isEnabled
        let isTactile = zone == .lesson
        let depth = isTactile ? (kind == .primary ? Spacing.buttonDepth : Spacing.buttonDepth - 2) : 0
        configuration.label
            .foregroundStyle(foreground)
            .background(face, in: shape)
            .overlay {
                if shimmers && isEnabled && !motion.reduceMotion {
                    ShimmerSweep().clipShape(shape)
                }
            }
            .overlay(shape.strokeBorder(kind == .secondary ? Color.stroke : .clear, lineWidth: 1.5))
            .offset(y: pressed && isTactile ? depth - 1 : 0)
            .background(shape.fill(isEnabled && isTactile ? depthColor : .clear).offset(y: depth))
            .padding(.bottom, depth)
            .scaleEffect(pressed && !isTactile ? motion.pressedScale : 1)
            .contentShape(shape)
            .animation(motion.animation(MotionTokens.press), value: pressed)
    }

    private var foreground: Color {
        guard isEnabled else { return .disabledInk }
        switch kind {
        case .primary: return .white
        case .secondary: return .ink
        case .destructive: return .errorInk
        }
    }

    private var face: Color {
        guard isEnabled else { return .disabledSurface }
        switch kind {
        case .primary: return .primaryAction
        case .secondary: return .surface
        case .destructive: return .errorSurface
        }
    }

    private var depthColor: Color {
        switch kind {
        case .primary: return .primaryDepth
        case .secondary: return .tileDepth
        case .destructive: return .errorDepth
        }
    }
}

/// A slanted band of light crossing the button, then a pause. Decorative only.
private struct ShimmerSweep: View {
    /// Horizontal unit-point range that starts and ends with the band fully off the button.
    private static let travel: ClosedRange<Double> = -0.6...1.3
    private static let bandWidth: Double = 0.3

    var body: some View {
        TimelineView(.animation) { context in
            let elapsed = context.date.timeIntervalSinceReferenceDate
                .truncatingRemainder(dividingBy: MotionTokens.shimmerCycle)
            let progress = min(elapsed / MotionTokens.shimmerSweep, 1)
            let x = Self.travel.lowerBound + progress * (Self.travel.upperBound - Self.travel.lowerBound)
            LinearGradient(
                colors: [.white.opacity(0), .white.opacity(0.35), .white.opacity(0)],
                startPoint: UnitPoint(x: x, y: 0),
                endPoint: UnitPoint(x: x + Self.bandWidth, y: 1)
            )
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
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
