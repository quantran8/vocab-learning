import SwiftUI

/// Horizontal shake driven by an animatable counter; each +1 is one full shake.
struct ShakeEffect: GeometryEffect {
    var travel: CGFloat = 6
    var animatableData: CGFloat

    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(CGAffineTransform(translationX: travel * sin(animatableData * .pi * 4), y: 0))
    }
}
