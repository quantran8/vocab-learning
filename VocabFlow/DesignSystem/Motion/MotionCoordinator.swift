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

private struct MotionCoordinatorKey: EnvironmentKey {
    static let defaultValue = MotionCoordinator(reduceMotion: false)
}

extension EnvironmentValues {
    var motion: MotionCoordinator {
        get { self[MotionCoordinatorKey.self] }
        set { self[MotionCoordinatorKey.self] = newValue }
    }
}
