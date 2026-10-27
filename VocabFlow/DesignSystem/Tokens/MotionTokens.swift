import SwiftUI

enum MotionTokens {
    static let press = Animation.easeOut(duration: 0.12)
    static let lift = Animation.spring(response: 0.24, dampingFraction: 0.82)
    static let snap = Animation.spring(response: 0.32, dampingFraction: 0.76)
    static let returnToOrigin = Animation.spring(response: 0.34, dampingFraction: 0.84)
    static let feedback = Animation.spring(response: 0.36, dampingFraction: 0.68)
    static let transition = Animation.timingCurve(0.2, 0.8, 0.2, 1, duration: 0.36)
    static let progress = Animation.easeOut(duration: 0.4)
    static let entrance = Animation.spring(response: 0.5, dampingFraction: 0.62)
    static let reducedCrossfade = Animation.easeInOut(duration: 0.15)

    static let pressedScale: CGFloat = 0.97
    static let liftedScale: CGFloat = 1.04
    static let pulseScale: CGFloat = 1.03
    static let enterOffset: CGFloat = 13
}
