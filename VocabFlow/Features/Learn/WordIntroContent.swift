import SwiftUI

/// The Learn word introduction: centered spelling hero (animated unless turned off) with IPA and audio,
/// then flat Part of speech, Meaning, Definition and In context sections separated by dividers.
struct WordIntroContent: View {
    let word: VocabularyItem
    let presentation: IntroductionPresentation
    /// Plays recorded audio when there is some; otherwise the word is spoken by the device.
    var playAudio: (() -> Void)?
    var animatesWord = true
    @Environment(SpeechPlayer.self) private var speech

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: Spacing.xs) {
                IntroMotionHost(word: word.term, presentation: presentation, animates: animatesWord)
                WordPronunciation(term: word.term, ipa: word.ipa, playAudio: playAudio)
            }
            // With the first section's top padding, this makes the 32pt gap between hero and information.
            .padding(.bottom, Spacing.m)

            // Meaning is always present, so anchoring dividers on it keeps them strictly between sections.
            if let partOfSpeech = word.partOfSpeechLabel {
                section("Part of speech") {
                    Text(verbatim: partOfSpeech)
                        .font(Typography.wordClass)
                        .foregroundStyle(Color.ink)
                }
                divider
            }

            section("Meaning") {
                Text(verbatim: word.meaningVi)
                    .font(Typography.wordMeaning)
                    .foregroundStyle(Color.ink)
                    .accessibilityLabel(Text("Vietnamese meaning: \(word.meaningVi)"))
            }

            if let definition = word.definitionEN {
                divider
                section("Definition") {
                    Text(verbatim: definition)
                        .font(Typography.body)
                        .foregroundStyle(Color.ink)
                }
            }

            if !word.example.isEmpty {
                divider
                section("In context") {
                    VStack(alignment: .leading, spacing: Spacing.s) {
                        Text(LearnView.highlight(word.term, in: word.example))
                            .font(Typography.body)
                            .foregroundStyle(Color.ink)
                        if let translation = word.exampleTranslation, !translation.isEmpty {
                            ExampleTranslation(text: translation)
                        }
                    }
                }
            }
        }
        .onDisappear { speech.stop() }
    }

    private var divider: some View {
        Rectangle()
            .fill(Color.stroke)
            .frame(height: 1)
    }

    private func section<Content: View>(_ title: LocalizedStringKey, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Eyebrow(text: title)
                .accessibilityAddTraits(.isHeader)
            content()
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, Spacing.m)
    }
}

/// IPA next to the play button. Plays recorded audio when there is some; otherwise the device speaks the word.
struct WordPronunciation: View {
    let term: String
    let ipa: String?
    var playAudio: (() -> Void)?
    @Environment(SpeechPlayer.self) private var speech

    var body: some View {
        HStack(spacing: Spacing.s) {
            if let ipa {
                Text(verbatim: ipa)
                    .font(Typography.body)
                    .foregroundStyle(Color.mutedInk)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityLabel(Text("IPA: \(ipa)"))
            }
            Button {
                if let playAudio {
                    playAudio()
                } else {
                    _ = speech.speak(term)
                }
            } label: {
                Image(systemName: speech.isAvailable ? "speaker.wave.2" : "speaker.slash")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(speech.isAvailable ? Color.interactive : Color.disabledInk)
                    .frame(width: Spacing.audioButton, height: Spacing.audioButton)
                    .background(
                        speech.isAvailable ? Color.selectedSurface : Color.disabledSurface,
                        in: RoundedRectangle(cornerRadius: Radii.audioButton, style: .continuous)
                    )
                    .contentShape(RoundedRectangle(cornerRadius: Radii.audioButton, style: .continuous))
            }
            .buttonStyle(PressScaleButtonStyle())
            .disabled(!speech.isAvailable)
            .accessibilityLabel(Text(speech.isAvailable ? "Play pronunciation" : "Audio unavailable"))
            .accessibilityValue(speech.isSpeaking ? Text("Playing") : Text(verbatim: ""))
        }
    }
}

/// The icon only identifies the line as a translation; it isn't a control.
struct ExampleTranslation: View {
    let text: String
    var showsIcon = true

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Spacing.xs) {
            if showsIcon {
                Image(systemName: "translate")
                    .accessibilityLabel(Text("Translation"))
            }
            Text(verbatim: text)
        }
        .font(Typography.secondary)
        .foregroundStyle(Color.mutedInk)
        .accessibilityElement(children: .combine)
    }
}
