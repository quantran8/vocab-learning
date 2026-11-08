import RiveRuntime
import SwiftUI

/// Plays one artboard of `syllie.riv` with its state machine and no view model input, e.g. `Loading` or `Celebrate`.
/// Decorative only: not hit-testable and hidden from VoiceOver.
struct SyllieArtboardView: View {
    let artboard: String
    let stateMachine: String

    @StateObject private var player = SyllieArtboardPlayer()

    var body: some View {
        Group {
            if let rive = player.rive {
                RiveUIViewRepresentable(rive: rive)
            } else {
                SwiftUI.Color.clear
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .task { await player.load(artboard: artboard, stateMachine: stateMachine) }
    }
}

@MainActor
private final class SyllieArtboardPlayer: ObservableObject {
    @Published private(set) var rive: Rive?

    func load(artboard name: String, stateMachine stateMachineName: String) async {
        guard rive == nil else { return }
        do {
            let file = try await SyllieFile.shared()
            let artboard = try await file.createArtboard(name)
            let stateMachine = try await artboard.createStateMachine(stateMachineName)
            rive = try await Rive(file: file, artboard: artboard, stateMachine: stateMachine, fit: .contain(alignment: .center))
        } catch {
            // Decorative: without the file Syllie just doesn't show.
        }
    }
}
