import SwiftUI

/// Large answer card used by Select Meaning and Audio Select.
struct ChoiceTileButton: View {
    let text: String
    let state: WordTileVisualState
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            WordTile(text: text, visualState: state)
        }
        .buttonStyle(.plain)
        .disabled(state == .disabled || state == .correct)
        .accessibilityLabel(Text("\(text), option"))
        .accessibilityValue(choiceValue)
        .accessibilityAddTraits(state == .selected ? [.isSelected] : [])
    }

    private var choiceValue: Text {
        switch state {
        case .selected: Text("Selected")
        case .correct: Text("Correct")
        case .incorrect: Text("Incorrect, already checked")
        case .disabled: Text("Unavailable")
        default: Text(verbatim: "")
        }
    }
}

extension TemplateRun {
    /// Visual state for a choice. The accepted answer is only marked after it is chosen.
    func choiceState(_ id: String, selected: String?) -> WordTileVisualState {
        if phase == .correct {
            return id == exercise.acceptedChoiceID ? .correct : .disabled
        }
        if selected == id { return .selected }
        if feedback == .wrongChoice(choiceID: id) { return .incorrect }
        return .idle
    }

    var incorrectChoiceID: String? {
        if case .wrongChoice(let id) = feedback { return id }
        return nil
    }
}

/// Context line shown above sentence-based exercises.
struct ContextNote: View {
    let text: String

    var body: some View {
        Label {
            Text(verbatim: text)
                .fixedSize(horizontal: false, vertical: true)
        } icon: {
            Image(systemName: "text.bubble")
                .accessibilityHidden(true)
        }
        .font(Typography.secondary)
        .foregroundStyle(Color.mutedInk)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.s)
        .background(Color.neutralSurface, in: RoundedRectangle(cornerRadius: Radii.tile, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("Context: \(text)"))
    }
}

/// Play/replay control plus an always-available written fallback, so sound is never required.
struct AudioCuePanel: View {
    let run: TemplateRun
    /// Written clue shown when audio is off; nil hides it (e.g. when it would reveal the answer).
    let fallbackClue: String?
    var isLarge = false

    @Environment(TemplateSandboxStore.self) private var sandbox

    var body: some View {
        VStack(spacing: Spacing.s) {
            AudioPlayButton(
                isSpeaking: sandbox.speech.isSpeaking,
                isAvailable: sandbox.speech.isAvailable,
                isLarge: isLarge
            ) {
                sandbox.playAudio()
            }

            Text(statusText)
                .font(Typography.micro)
                .foregroundStyle(Color.mutedInk)
                .multilineTextAlignment(.center)

            if run.usesAudioFallback {
                VStack(spacing: Spacing.xxs) {
                    Text(sandbox.speech.isAvailable ? "Listening off — use this clue instead" : "Audio isn’t available on this device")
                        .font(Typography.micro.weight(.bold))
                        .foregroundStyle(Color.selectedInk)
                    if let fallbackClue {
                        Text(verbatim: fallbackClue)
                            .font(Typography.body.weight(.semibold))
                            .foregroundStyle(Color.ink)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(Spacing.s)
                .background(Color.selectedSurface, in: RoundedRectangle(cornerRadius: Radii.tile, style: .continuous))
                .accessibilityElement(children: .combine)
            } else {
                Button("Can’t listen now?") { sandbox.useAudioFallback() }
                    .font(Typography.secondary.weight(.bold))
                    .foregroundStyle(Color.selectedInk)
                    .frame(minHeight: Spacing.minTouchTarget)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.l)
        .padding(.horizontal, Spacing.m)
        .cardSurface()
        .onAppear {
            if !sandbox.speech.isAvailable { sandbox.useAudioFallback() }
        }
    }

    private var statusText: LocalizedStringKey {
        if !sandbox.speech.isAvailable { return "Sound can’t play here." }
        switch run.audioPlayCount {
        case 0: return "Tap to listen. Nothing plays automatically."
        case 1: return "Played once · tap to replay"
        default: return "Played \(run.audioPlayCount) times · tap to replay"
        }
    }
}

/// Word Stack board bound to the sandbox. Tap and drag both place the tile; only Check submits.
struct SandboxStackBoard: View {
    let run: TemplateRun
    @Binding var placedTileID: String?
    @Binding var isDragging: Bool

    @Environment(TemplateSandboxStore.self) private var sandbox

    var body: some View {
        WordStackBoard(
            prompt: run.exercise.prompt,
            options: run.exercise.choices ?? [],
            placedTileID: $placedTileID,
            correctTileID: run.phase == .correct ? run.exercise.acceptedChoiceID : nil,
            incorrectTileID: run.incorrectChoiceID,
            isLocked: run.phase == .incorrect,
            isDragging: $isDragging,
            haptics: sandbox.haptics
        )
    }
}

extension TemplateVariant {
    /// Visible marker for non-default variants; the base framing shows none.
    var chipTitle: LocalizedStringKey? {
        switch self {
        case .gloss, .sentence: nil
        case .meaningClash: "Meaning Clash"
        case .fillBlank: "Fill the Blank"
        case .phrase: "Phrase Snap"
        }
    }
}

/// A sentence with one visible blank, filled in once the exercise is resolved.
struct SentenceCard: View {
    let sentence: String
    let answer: String?

    var body: some View {
        Text(attributed)
            .font(Typography.sentence)
            .foregroundStyle(Color.ink)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity)
            .padding(.vertical, Spacing.xl)
            .padding(.horizontal, Spacing.m)
            .background(Color.neutralSurface, in: RoundedRectangle(cornerRadius: Radii.card, style: .continuous))
            .accessibilityLabel(Text(sentence.replacingOccurrences(of: BuildChallenge.blank, with: answer ?? String(localized: "blank"))))
    }

    private var attributed: AttributedString {
        let parts = sentence.components(separatedBy: BuildChallenge.blank)
        var result = AttributedString(parts.first ?? "")
        var middle = AttributedString(answer ?? "_____")
        middle.foregroundColor = answer == nil ? Color.interactive : Color.successInk
        result += middle
        result += AttributedString(parts.dropFirst().joined(separator: BuildChallenge.blank))
        return result
    }
}
