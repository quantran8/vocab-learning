import SwiftUI

/// Animated Learn: an animated English-spelling hero, then static Meaning, Definition and
/// In context sections. Only the hero animates; Next is never gated by motion.
struct LearnView: View {
    let index: Int
    @Environment(SessionStore.self) private var store

    var body: some View {
        let word = store.content.words[index]
        WordIntroContent(word: word, presentation: word.introPresentation)
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
