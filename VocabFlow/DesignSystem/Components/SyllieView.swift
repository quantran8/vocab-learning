import RiveRuntime
import SwiftUI

/// Syllie's moods. Raw values are the `Mood` enum keys in `syllie.riv`.
enum SyllieMood: String, CaseIterable, Identifiable {
    case idle, happy, excited, thinking, oops, sleepy
    /// Short happy variants, each a different gesture. `proud` is for a recall streak or a notable result.
    case happyPop, happyWiggle, happyPuff, happyFloat, proud
    /// Wrong-answer variants, each a different gesture.
    case oopsSquish, oopsWobble, oopsFreeze, oopsSlip
    /// One-shot from `sleepy` back to awake; `SyllieView(onWake:)` plays it on a tap.
    case wakeUp
    /// A stronger breathing loop than `idle` (bigger stretch and lift), for where Syllie is shown small.
    case breath
    /// One-shot "I'm ready" nod (tips back, dips down, settles). It starts from `reviewWatch`'s loop-boundary pose.
    case reviewReady
    /// Loop while a word list is arriving: leans toward it and scans it left to right, again and again.
    /// Each loop starts and ends with the eyes centred, the pose `reviewReady` starts from.
    case reviewWatch
    /// One-shot for "review done, new words next": puffs up proudly (top-right lobe up, eyes squeezed), leans
    /// down to look at the list below, then stretches up eager to start, and settles in the rest pose.
    case reviewToLearn
    /// 2 s one-shot into "hmm, let me think": a quick inhale (eyes widen), then the left eye squints to a line
    /// while the right eye looks up-right, the head cocks ~4° and the body scrunches ~5%; a small "hmm" nod and
    /// one top-right lobe throb. It ends on the pose `deepThoughtHold` loops on; `SyllieReactionView` moves on to
    /// it, so Syllie keeps thinking instead of looking done.
    case deepThought
    /// 3 s loop that holds the `deepThought` pose: two lobe/body throbs ("brain working"), then the eyes swap
    /// (left opens looking up-left, right squints, head tilts the other way) and swap back.
    /// Nothing goes back to rest until the mood changes.
    case deepThoughtHold
    var id: Self { self }

    /// The right-answer reactions, picked at random so Syllie doesn't repeat one gesture. `proud` is kept for streaks.
    static let happyReactions: [SyllieMood] = [.happy, .happyPop, .happyWiggle, .happyPuff, .happyFloat]
    /// The wrong-answer reactions, picked at random the same way.
    static let oopsReactions: [SyllieMood] = [.oops, .oopsSquish, .oopsWobble, .oopsFreeze, .oopsSlip]

    /// Length of one `reviewWatch` loop in `syllie.riv`; switch to `reviewReady` on a multiple of it so the nod
    /// picks up from the same pose.
    static let reviewWatchLoop: Double = 1.6

    /// The loops shown while a practice question is unanswered, picked at random per question.
    static let thinkingMoods: [SyllieMood] = [.thinking, .deepThought]

    /// A random unanswered-question loop.
    static func nextThinking() -> SyllieMood { thinkingMoods.randomElement() ?? .thinking }
    /// A random right-answer reaction.
    static func nextHappyReaction() -> SyllieMood { happyReactions.randomElement() ?? .happy }
    /// A random wrong-answer reaction.
    static func nextOopsReaction() -> SyllieMood { oopsReactions.randomElement() ?? .oops }
}

/// Syllie the mascot, from the `Syllie` artboard / `Syllie` state machine of `syllie.riv`.
/// The view model `Syllie` has `mood` (enum `Mood`) and `react` (trigger, replays the current mood).
/// Decorative, except that with `onWake` a sleepy Syllie is a button: a tap plays `wakeUp`, then calls `onWake`.
/// With reduced motion Syllie still shows the mood's pose but doesn't loop or replay.
struct SyllieView: View {
    let mood: SyllieMood
    /// Change it (e.g. a counter) to replay the current mood, like a second correct answer in a row.
    var replayToken: Int = 0
    /// Called once a tap has woken a `sleepy` Syllie; the caller then moves him on (usually to `idle`).
    var onWake: (() -> Void)?

    @Environment(\.motion) private var motion
    @StateObject private var player = SylliePlayer()
    @State private var isWaking = false

    private var shownMood: SyllieMood { isWaking ? .wakeUp : mood }
    private var canWake: Bool { mood == .sleepy && onWake != nil && !isWaking }

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
        .task { await player.load(mood: shownMood) }
        .onChange(of: shownMood) { _, newValue in player.setMood(newValue) }
        .onChange(of: mood) { _, _ in isWaking = false }
        .onChange(of: replayToken) { _, _ in
            guard !motion.reduceMotion else { return }
            player.react()
        }
    }

    private func wake() {
        guard canWake, let onWake else { return }
        guard !motion.reduceMotion, let duration = SyllieMood.wakeUp.reactionDuration else {
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

/// Loads the `Syllie` artboard and keeps the view model instance bound to its state machine,
/// so the view can set `mood` and fire `react`.
@MainActor
private final class SylliePlayer: ObservableObject {
    @Published private(set) var rive: Rive?
    private var instance: ViewModelInstance?
    private var mood: SyllieMood?

    private static let moodProperty = EnumProperty(path: "mood")
    private static let reactProperty = TriggerProperty(path: "react")

    func load(mood: SyllieMood) async {
        self.mood = mood
        guard rive == nil else { return }
        do {
            let file = try await SyllieFile.shared()
            let artboard = try await file.createArtboard("Syllie")
            let instance = try await file.createViewModelInstance(.viewModelDefault(from: .artboardDefault(artboard)))
            // The mood may have changed while loading.
            instance.setValue(of: Self.moodProperty, to: (self.mood ?? mood).rawValue)
            let stateMachine = try await artboard.createStateMachine("Syllie", binding: instance)
            self.instance = instance
            rive = try await Rive(file: file, artboard: artboard, stateMachine: stateMachine, fit: .contain(alignment: .center))
        } catch {
            // Decorative: without the file Syllie just doesn't show.
        }
    }

    func setMood(_ mood: SyllieMood) {
        self.mood = mood
        instance?.setValue(of: Self.moodProperty, to: mood.rawValue)
    }

    func react() {
        instance?.fire(trigger: Self.reactProperty)
    }
}

/// `syllie.riv`, loaded once on one Rive worker and reused by every Syllie on screen.
@MainActor
enum SyllieFile {
    private static var loading: Task<RiveRuntime.File, Error>?

    static func shared() async throws -> RiveRuntime.File {
        if let loading { return try await loading.value }
        let task = Task { @MainActor in
            let worker = try await Worker()
            return try await RiveRuntime.File(source: .local("syllie", .main), worker: worker)
        }
        loading = task
        do {
            return try await task.value
        } catch {
            loading = nil
            throw error
        }
    }
}

#Preview {
    SyllieView(mood: .happy)
        .frame(width: 240, height: 200)
}
