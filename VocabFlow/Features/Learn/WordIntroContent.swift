import SwiftUI

/// The Learn word introduction: spelling hero (animated unless turned off) with IPA and audio, then flat
/// Part of speech, Meaning, Definition and In context sections separated by whitespace only.
struct WordIntroContent: View {
    let word: VocabularyItem
    let presentation: IntroductionPresentation
    /// Plays recorded audio when there is some; otherwise the word is spoken by the device.
    var playAudio: (() -> Void)?
    var animatesWord = true
    @Environment(SpeechPlayer.self) private var speech
    @ScaledMetric(relativeTo: .title3) private var ipaSize: CGFloat = 21
    @ScaledMetric(relativeTo: .body) private var audioIconSize: CGFloat = 19

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: Spacing.xs) {
                IntroMotionHost(word: word.term, presentation: presentation, animates: animatesWord)
                pronunciation
            }
            .padding(.bottom, Spacing.xl)

            if let partOfSpeech = word.partOfSpeechLabel {
                section("Part of speech") {
                    Text(verbatim: partOfSpeech)
                        .font(Typography.body)
                        .foregroundStyle(Color.ink)
                }
            }

            section("Meaning") {
                Text(verbatim: word.meaningVi)
                    .font(Typography.headerTitle)
                    .foregroundStyle(Color.ink)
                    .accessibilityLabel(Text("Vietnamese meaning: \(word.meaningVi)"))
            }

            if let definition = word.definitionEN {
                section("Definition") {
                    Text(verbatim: definition)
                        .font(Typography.body)
                        .foregroundStyle(Color.ink)
                }
            }

            if !word.example.isEmpty {
                section("In context") {
                    VStack(alignment: .leading, spacing: Spacing.xxs) {
                        Text(LearnView.highlight(word.term, in: word.example))
                            .font(Typography.body)
                            .foregroundStyle(Color.ink)
                        if let translation = word.exampleTranslation, !translation.isEmpty {
                            Text(verbatim: translation)
                                .font(Typography.secondary)
                                .foregroundStyle(Color.mutedInk)
                        }
                    }
                }
            }
        }
        .onDisappear { speech.stop() }
    }

    private var pronunciation: some View {
        HStack(spacing: Spacing.xs) {
            if let ipa = word.ipa {
                Text(verbatim: ipa)
                    .font(.system(size: ipaSize, weight: .medium))
                    .foregroundStyle(Color.mutedInk)
                    .accessibilityLabel(Text("IPA: \(ipa)"))
            }
            Button {
                if let playAudio {
                    playAudio()
                } else {
                    _ = speech.speak(word.term)
                }
            } label: {
                Image(systemName: speech.isAvailable ? "speaker.wave.2" : "speaker.slash")
                    .font(.system(size: audioIconSize, weight: .medium))
                    .foregroundStyle(speech.isAvailable ? Color.mutedInk : Color.disabledInk)
                    .frame(width: Spacing.minTouchTarget, height: Spacing.minTouchTarget)
                    .contentShape(Rectangle())
            }
            .buttonStyle(PressScaleButtonStyle())
            .disabled(!speech.isAvailable)
            .padding(.horizontal, -Spacing.xs)
            .accessibilityLabel(Text(speech.isAvailable ? "Play pronunciation" : "Audio unavailable"))
            .accessibilityValue(speech.isSpeaking ? Text("Playing") : Text(verbatim: ""))
        }
    }

    private func section<Content: View>(_ title: LocalizedStringKey, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Eyebrow(text: title)
                .accessibilityAddTraits(.isHeader)
            content()
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.bottom, Spacing.xl)
    }
}
