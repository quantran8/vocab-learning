import SwiftUI

enum MotionTokens {
    static let press = Animation.easeOut(duration: 0.12)
    static let lift = Animation.spring(response: 0.24, dampingFraction: 0.82)
    static let snap = Animation.spring(response: 0.32, dampingFraction: 0.76)
    /// Time for a `snap` move to come to rest.
    static let snapSettle: Double = 0.4
    /// A cloze word flying between the bank and the blank.
    static let wordFlight = Animation.spring(response: 0.22, dampingFraction: 0.88)
    /// Time for a `wordFlight` move to come to rest.
    static let wordFlightSettle: Double = 0.26
    static let returnToOrigin = Animation.spring(response: 0.34, dampingFraction: 0.84)
    static let feedback = Animation.spring(response: 0.36, dampingFraction: 0.68)
    /// One full wrong-answer shake.
    static let shake = Animation.linear(duration: 0.4)
    static let transitionDuration: Double = 0.36
    static let transition = Animation.timingCurve(0.2, 0.8, 0.2, 1, duration: transitionDuration)
    /// A step sliding in a flow that goes both ways: eases in and settles without overshoot, like a system push.
    static let stepSlide = Animation.spring(response: 0.4, dampingFraction: 1)
    static let progress = Animation.easeOut(duration: 0.4)
    static let entrance = Animation.spring(response: 0.5, dampingFraction: 0.62)
    static let reducedCrossfade = Animation.easeInOut(duration: 0.15)
    /// Time for the shimmer band to cross a button.
    static let shimmerSweep: Double = 1.4
    /// Time from one shimmer sweep to the next, including the pause between them.
    static let shimmerCycle: Double = 4

    // Word introduction recipes (visual only — never a navigation gate)
    static let introLetter = Animation.spring(response: 0.38, dampingFraction: 0.82)
    static let introBounce = Animation.spring(response: 0.36, dampingFraction: 0.58)
    static let introReveal = Animation.easeOut(duration: 0.28)
    static let introAccent = Animation.spring(response: 0.32, dampingFraction: 0.75)
    static let introSweep = Animation.easeInOut(duration: 0.75)
    static let introLetterStagger: Double = 0.055
    static let introChunkStagger: Double = 0.22
    static let introChunkHold: Double = 0.45

    // Review list before a session (visual only — never a navigation gate)
    static let reviewTileLanding = Animation.spring(response: 0.78, dampingFraction: 0.76)
    static let reviewTileStagger: Double = 0.11
    static let reviewTrainLanding = Animation.spring(response: 0.42, dampingFraction: 0.9)
    static let reviewTrainStagger: Double = 0.2
    /// Time for the last word to come to rest after its entrance starts.
    static let reviewSettle: Double = 0.9
    static let reviewWigglePause: ClosedRange<Double> = 1.1...2.4
    static let streamCharacter: Double = 0.022

    // End-of-session results (visual only)
    static let celebrationStatsDelay: Double = 0.25
    static let celebrationStagger: Double = 0.08

    static let pressedScale: CGFloat = 0.97
    static let liftedScale: CGFloat = 1.04
    static let pulseScale: CGFloat = 1.03
    static let enterOffset: CGFloat = 13
}
