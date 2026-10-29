import SwiftUI

/// The Learn word introduction: animated spelling hero with IPA and audio, then flat
/// Meaning, Definition and In context sections separated by hairlines.
struct WordIntroContent: View {
    let word: VocabularyItem
    let presentation: IntroductionPresentation
    @Environment(SpeechPlayer.self) private var speech

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: Spacing.xs) {
                IntroMotionHost(word: word.term, presentation: presentation)
                pronunciation
            }
            .padding(.bottom, Spacing.l)

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
                    Text(LearnView.highlight(word.term, in: word.example))
                        .font(Typography.body)
                        .foregroundStyle(Color.ink)
                }
            }
        }
        .onDisappear { speech.stop() }
    }

    private var pronunciation: some View {
        HStack(spacing: Spacing.xs) {
            if let ipa = word.ipa {
                Text(verbatim: ipa)
                    .font(Typography.secondary)
                    .foregroundStyle(Color.mutedInk)
                    .accessibilityLabel(Text("IPA: \(ipa)"))
            }
            Button {
                _ = speech.speak(word.term)
            } label: {
                Image(systemName: speech.isAvailable ? "speaker.wave.2" : "speaker.slash")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(speech.isAvailable ? Color.selectedInk : Color.disabledInk)
                    .frame(width: 32, height: 32)
                    .background(
                        speech.isAvailable ? Color.selectedSurface : Color.disabledSurface,
                        in: RoundedRectangle(cornerRadius: Radii.chip, style: .continuous)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: Radii.chip, style: .continuous)
                            .strokeBorder(speech.isSpeaking ? Color.interactive : Color.clear, lineWidth: 1.5)
                    )
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
            Rectangle()
                .fill(Color.stroke)
                .frame(height: 1)
                .padding(.bottom, Spacing.m)
            Eyebrow(text: title)
                .accessibilityAddTraits(.isHeader)
            content()
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.bottom, Spacing.l)
    }
}
