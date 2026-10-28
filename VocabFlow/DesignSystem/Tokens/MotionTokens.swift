import SwiftUI

enum MotionTokens {
    static let press = Animation.easeOut(duration: 0.12)
    static let lift = Animation.spring(response: 0.24, dampingFraction: 0.82)
    static let snap = Animation.spring(response: 0.32, dampingFraction: 0.76)
    static let returnToOrigin = Animation.spring(response: 0.34, dampingFraction: 0.84)
    static let feedback = Animation.spring(response: 0.36, dampingFraction: 0.68)
    static let transitionDuration: Double = 0.36
    static let transition = Animation.timingCurve(0.2, 0.8, 0.2, 1, duration: transitionDuration)
    static let progress = Animation.easeOut(duration: 0.4)
    static let entrance = Animation.spring(response: 0.5, dampingFraction: 0.62)
    static let reducedCrossfade = Animation.easeInOut(duration: 0.15)

    // Word introduction recipes (visual only — never a navigation gate)
    static let introLetter = Animation.spring(response: 0.38, dampingFraction: 0.82)
    static let introBounce = Animation.spring(response: 0.36, dampingFraction: 0.58)
    static let introReveal = Animation.easeOut(duration: 0.28)
    static let introAccent = Animation.spring(response: 0.32, dampingFraction: 0.75)
    static let introSweep = Animation.easeInOut(duration: 0.75)
    static let introLetterStagger: Double = 0.055
    static let introChunkStagger: Double = 0.22
    static let introChunkHold: Double = 0.45

    static let pressedScale: CGFloat = 0.97
    static let liftedScale: CGFloat = 1.04
    static let pulseScale: CGFloat = 1.03
    static let enterOffset: CGFloat = 13
}
