import SwiftUI

/// End-of-session celebration: the `Celebrate` artboard of `syllie.riv` (Syllie flies in from the top left, loops,
/// lands near the top of the screen, bounces twice, then sways happily in a loop). Meant to cover the whole screen. Decorative only.
struct SyllieCelebrationView: View {
    /// When Syllie nears the top of its loop: the moment for the confetti.
    static let confettiCue: Duration = .seconds(1.1)

    var body: some View {
        SyllieArtboardView(artboard: "Celebrate", stateMachine: "Celebrate")
    }
}
