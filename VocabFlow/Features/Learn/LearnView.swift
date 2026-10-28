import SwiftUI

/// Animated Learn: an animated English-spelling hero, then static Meaning, Pronunciation and
/// Definition / In context sections. Only the hero animates; Next is never gated by motion.
struct LearnView: View {
    let index: Int
    @Environment(SessionStore.self) private var store
    /// Demo motion selector. Local and per word, so a redraw never changes the recipe.
    @State private var selectedTemplate: IntroductionTemplateID?

    var body: some View {
        let word = store.content.words[index]
        let presentation = selectedTemplate.map { word.introPresentation.switched(to: $0, for: word.term) }
            ?? word.introPresentation

        VStack(spacing: Spacing.l) {
            StageIntro(
                number: 1,
                label: "Meet the words",
                title: String(localized: "Meet your next word."),
                subtitle: "Word \(index + 1) of \(store.totalWords)",
                systemImage: "book.fill"
            )

            WordIntroContent(word: word, presentation: presentation) {
                motionMenu(current: presentation.templateID)
            }
        }
    }

    private func motionMenu(current: IntroductionTemplateID) -> some View {
        Menu {
            Picker(selection: Binding(get: { current }, set: { selectedTemplate = $0 })) {
                ForEach(IntroductionTemplateID.allCases) { id in
                    Text(id.title).tag(id)
                }
            } label: {
                Text("Intro motion")
            }
        } label: {
            HStack(spacing: Spacing.xxs) {
                Text(current.title)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption.weight(.bold))
                    .accessibilityHidden(true)
            }
            .font(Typography.micro.weight(.bold))
            .foregroundStyle(Color.mutedInk)
            .padding(.horizontal, Spacing.s)
            .frame(minHeight: Spacing.minTouchTarget)
        }
        .accessibilityLabel(Text("Intro motion: \(Text(current.title))"))
    }

    static func highlight(_ term: String, in sentence: String) -> AttributedString {
        var attributed = AttributedString(sentence)
        if let range = attributed.range(of: term, options: .caseInsensitive) {
            attributed[range].inlinePresentationIntent = .stronglyEmphasized
            attributed[range].foregroundColor = Color.selectedInk
        }
        return attributed
    }
}
