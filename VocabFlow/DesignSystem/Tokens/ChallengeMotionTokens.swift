import SwiftUI

/// Match Madness timing. Kept short on purpose: nothing on the board blocks the next tap for more than ~200 ms.
extension MotionTokens {
    /// How long a matched pair shows as correct before it fades out.
    static let matchCorrectHold: Double = 0.3
    /// A matched pair fading out of its slots.
    static let matchFadeOut = Animation.easeOut(duration: 0.16)
    /// The next pair fading into the freed slots, once the matched pair is mostly gone.
    static let matchFadeIn = Animation.easeOut(duration: 0.22).delay(0.12)
    /// A wrong pair's shake (one full `ShakeEffect` cycle).
    static let matchShake = Animation.linear(duration: 0.18)
    /// How long the full-screen celebration stays over the results before it clears.
    static let challengeCelebrationHold: Double = 2.6
    /// Every this many matches in a row, Syllie gives a small cheer.
    static let comboMilestone = 5
}

extension MotionTokens {
    /// The "Start" callout over the current map level bobbing up and down.
    static let mapCalloutBob = Animation.easeInOut(duration: 0.9).repeatForever(autoreverses: true)
}
