import RiveRuntime
import SwiftUI

/// What Syllie is doing on Home. Raw values are the `HomeScene` enum keys in `syllie.riv`.
enum HomeSyllieScene: String, CaseIterable {
    case idle, sleepy
    /// One-shot from `sleepy` back to awake; `HomeSyllieView(onWake:)` plays it on a tap.
    case wakeUp
    /// One-shot: a letter "A" flies in, Syllie bounces it up with his top lobe, it falls and bounces, he's pleased.
    case playLetters
    /// One-shot: a paper plane flies in, loops once over Syllie's head (he sways along), zooms off to the right,
    /// Syllie leans after it, stands puzzled, then settles.
    case planeChase

    /// The play scenes Home picks from while Syllie is awake.
    static let plays: [HomeSyllieScene] = [.playLetters, .planeChase]

    /// How long the scene's one-shot timeline in `syllie.riv` runs (plus the blend into it) before Syllie can go
    /// back to idle. Nil for scenes that loop and are held until the next one.
    var duration: Duration? {
        switch self {
        case .wakeUp: .seconds(1.0)
        case .playLetters: .seconds(5.7)
        case .planeChase: .seconds(5.2)
        case .idle, .sleepy: nil
        }
    }
}

/// Syllie on Home, from the `HomeSyllie` artboard / `HomeSyllie` state machine of `syllie.riv`: its own copy of Syllie
/// plus the letter and paper-plane props, so the play scenes don't touch the shared `Syllie` artboard.
/// The view model `HomeSyllie` has `scene` (enum `HomeScene`).
/// Decorative, except that with `onWake` a sleeping Syllie is a button: a tap plays `wakeUp`, then calls `onWake`.
struct HomeSyllieView: View {
    let scene: HomeSyllieScene
    /// Called once a tap has woken a sleeping Syllie; the caller then moves him on (usually to `idle`).
    var onWake: (() -> Void)?

    @Environment(\.motion) private var motion
    @StateObject private var player = HomeSylliePlayer()
    @State private var isWaking = false

    private var shownScene: HomeSyllieScene { isWaking ? .wakeUp : scene }
    private var canWake: Bool { scene == .sleepy && onWake != nil && !isWaking }

    var body: some View {
        Group {
            if let rive = player.rive {
                RiveUIViewRepresentable(rive: rive)
            } else {
                SwiftUI.Color.clear
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { wake() }
        .allowsHitTesting(canWake)
        .accessibilityElement()
        .accessibilityHidden(!canWake)
        .accessibilityLabel(Text("Syllie is asleep"))
        .accessibilityHint(Text("Double-tap to wake him up"))
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { wake() }
        .task { await player.load(scene: shownScene) }
        .onChange(of: shownScene) { _, newValue in player.setScene(newValue) }
        .onChange(of: scene) { _, _ in isWaking = false }
    }

    private func wake() {
        guard canWake, let onWake else { return }
        guard !motion.reduceMotion, let duration = HomeSyllieScene.wakeUp.duration else {
            onWake()
            return
        }
        isWaking = true
        Task {
            try? await Task.sleep(for: duration)
            guard isWaking else { return }
            isWaking = false
            onWake()
        }
    }
}

/// Loads the `HomeSyllie` artboard and keeps its view model instance bound to the state machine, so the view
/// can set `scene`.
@MainActor
private final class HomeSylliePlayer: ObservableObject {
    @Published private(set) var rive: Rive?
    private var instance: ViewModelInstance?
    private var scene: HomeSyllieScene?

    private static let sceneProperty = EnumProperty(path: "scene")

    func load(scene: HomeSyllieScene) async {
        self.scene = scene
        guard rive == nil else { return }
        do {
            let file = try await SyllieFile.shared()
            let artboard = try await file.createArtboard("HomeSyllie")
            let instance = try await file.createViewModelInstance(.viewModelDefault(from: .artboardDefault(artboard)))
            // The scene may have changed while loading.
            instance.setValue(of: Self.sceneProperty, to: (self.scene ?? scene).rawValue)
            let stateMachine = try await artboard.createStateMachine("HomeSyllie", binding: instance)
            self.instance = instance
            rive = try await Rive(file: file, artboard: artboard, stateMachine: stateMachine, fit: .contain(alignment: .center))
        } catch {
            // Decorative: without the file Syllie just doesn't show.
        }
    }

    func setScene(_ scene: HomeSyllieScene) {
        self.scene = scene
        instance?.setValue(of: Self.sceneProperty, to: scene.rawValue)
    }
}

#Preview {
    HomeSyllieView(scene: .playLetters)
        .frame(width: 240, height: 260)
}
