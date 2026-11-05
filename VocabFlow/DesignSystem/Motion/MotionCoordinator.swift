import SwiftUI

struct MotionCoordinator {
    let reduceMotion: Bool

    var pressedScale: CGFloat { reduceMotion ? 1 : MotionTokens.pressedScale }
    var liftedScale: CGFloat { reduceMotion ? 1 : MotionTokens.liftedScale }
    var pulseScale: CGFloat { reduceMotion ? 1 : MotionTokens.pulseScale }

    var routeTransition: AnyTransition {
        reduceMotion
            ? .opacity
            : .asymmetric(
                insertion: .opacity.combined(with: .offset(y: MotionTokens.enterOffset)),
                removal: .opacity
            )
    }

    /// Step-to-step content inside the flow: new content slides in from the right, old exits left.
    var stepTransition: AnyTransition {
        reduceMotion
            ? .opacity
            : .asymmetric(
                insertion: .move(edge: .trailing).combined(with: .opacity),
                removal: .move(edge: .leading).combined(with: .opacity)
            )
    }

    /// `stepTransition` for a flow that also goes back. `isMovingBack` is read as the transition runs:
    /// an outgoing view keeps the transition it was last given, so a plain value would be one step late.
    func stepTransition(isMovingBack: @escaping @MainActor () -> Bool) -> AnyTransition {
        reduceMotion ? .opacity : AnyTransition(DirectionalStepTransition(isMovingBack: isMovingBack))
    }

    var popTransition: AnyTransition {
        reduceMotion ? .opacity : .scale(scale: 0.88).combined(with: .opacity)
    }

    func animation(_ animation: Animation) -> Animation {
        reduceMotion ? MotionTokens.reducedCrossfade : animation
    }

    func travel(_ animation: Animation) -> Animation? {
        reduceMotion ? nil : animation
    }

    func perform<Result>(_ animation: Animation, _ body: () throws -> Result) rethrows -> Result {
        try withAnimation(self.animation(animation), body)
    }
}

/// Like a system push: the page on top travels the full width while the one beneath shifts only a little.
private struct DirectionalStepTransition: Transition {
    /// How far the page beneath shifts, as a share of the width.
    private static let parallax: CGFloat = 0.3

    let isMovingBack: @MainActor () -> Bool

    func body(content: Content, phase: TransitionPhase) -> some View {
        let isBack = isMovingBack()
        let offset: CGFloat = switch phase {
        case .willAppear: isBack ? -Self.parallax : 1
        case .didDisappear: isBack ? 1 : -Self.parallax
        default: 0
        }
        return content
            .visualEffect { effect, geometry in
                effect.offset(x: offset * geometry.size.width)
            }
            .opacity(phase.isIdentity ? 1 : 0)
    }
}

private struct MotionCoordinatorKey: EnvironmentKey {
    static let defaultValue = MotionCoordinator(reduceMotion: false)
}

extension EnvironmentValues {
    var motion: MotionCoordinator {
        get { self[MotionCoordinatorKey.self] }
        set { self[MotionCoordinatorKey.self] = newValue }
    }
}
