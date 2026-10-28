import SwiftUI

/// The word introduction body: spelling hero, then static Meaning, Pronunciation and
/// Definition / In context sections. Shared by Learn and the My Words detail sheet.
/// With a presentation the hero animates (Learn); without one it shows the word at rest.
struct WordIntroContent<Accessory: View>: View {
    let word: VocabularyItem
    let presentation: IntroductionPresentation?
    @ViewBuilder let accessory: Accessory
    @Environment(SpeechPlayer.self) private var speech
    @ScaledMetric(relativeTo: .largeTitle) private var heroFontSize: CGFloat = 48

    var body: some View {
        VStack(spacing: Spacing.l) {
            hero
                .cardSurface()

            section("Meaning") {
                Text(verbatim: word.meaningVi)
                    .font(Typography.headerTitle)
                    .foregroundStyle(Color.ink)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityLabel(Text("Vietnamese meaning: \(word.meaningVi)"))
            }

            if let ipa = word.ipa {
                section("Pronunciation") {
                    HStack(spacing: Spacing.m) {
                        Text(verbatim: ipa)
                            .font(Typography.emphasis)
                            .foregroundStyle(Color.ink)
                            .accessibilityLabel(Text("IPA: \(ipa)"))
                        Spacer(minLength: 0)
                        AudioPlayButton(isSpeaking: speech.isSpeaking, isAvailable: speech.isAvailable) {
                            _ = speech.speak(word.term)
                        }
                    }
                }
            }

            if word.definitionEN != nil || !word.example.isEmpty {
                section("Definition") {
                    VStack(alignment: .leading, spacing: Spacing.s) {
                        if let definition = word.definitionEN {
                            Text(verbatim: definition)
                                .font(Typography.body)
                                .foregroundStyle(Color.ink)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        if !word.example.isEmpty {
                            Eyebrow(text: "In context")
                            Text(LearnView.highlight(word.term, in: word.example))
                                .font(Typography.body)
                                .foregroundStyle(Color.ink)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
        }
        .onDisappear { speech.stop() }
    }

    @ViewBuilder
    private var hero: some View {
        if let presentation {
            IntroMotionHost(word: word.term, presentation: presentation) {
                accessory
            }
            .padding(.horizontal, Spacing.m)
            .padding(.top, Spacing.l)
            .padding(.bottom, Spacing.xs)
        } else {
            // Same type treatment as the settled IntroMotionHost stage.
            Text(verbatim: word.term)
                .font(.system(size: heroFontSize, weight: .heavy))
                .tracking(-0.5)
                .foregroundStyle(Color.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.4)
                .frame(maxWidth: .infinity, minHeight: heroFontSize * 2.2)
                .padding(.horizontal, Spacing.m)
                .padding(.vertical, Spacing.m)
                .accessibilityAddTraits(.isHeader)
        }
    }

    private func section<Content: View>(_ title: LocalizedStringKey, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Eyebrow(text: title)
                .accessibilityAddTraits(.isHeader)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.m)
        .background(Color.neutralSurface, in: RoundedRectangle(cornerRadius: Radii.card, style: .continuous))
    }
}

extension WordIntroContent where Accessory == EmptyView {
    /// Static hero: the word without its intro motion.
    init(word: VocabularyItem) {
        self.init(word: word, presentation: nil) { EmptyView() }
    }
}
