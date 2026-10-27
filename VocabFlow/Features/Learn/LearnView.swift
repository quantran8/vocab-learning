import SwiftUI

struct LearnView: View {
    let index: Int
    @Environment(SessionStore.self) private var store
    @Environment(\.motion) private var motion

    var body: some View {
        let word = store.content.words[index]
        let isLast = index + 1 >= store.totalWords

        FlowScaffold(stage: "Learn", stageCurrent: index + 1, stageTotal: store.totalWords) {
            VStack(spacing: Spacing.xl) {
                StageIntro(
                    number: 1,
                    label: "Meet the words",
                    title: String(localized: "Word \(index + 1) of \(store.totalWords)"),
                    subtitle: "Read the meaning and example before you practise.",
                    systemImage: "book.fill"
                )

                VStack(spacing: Spacing.m) {
                    Eyebrow(text: "New word")
                    Text(verbatim: word.term)
                        .font(Typography.display)
                        .tracking(Typography.tightTracking)
                        .foregroundStyle(Color.ink)
                        .multilineTextAlignment(.center)
                    Text(verbatim: word.meaningVi)
                        .font(Typography.emphasis)
                        .foregroundStyle(Color.primarySoftInk)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, Spacing.m)
                        .padding(.vertical, Spacing.xs)
                        .background(Color.primarySoft, in: Capsule())
                        .accessibilityLabel(Text("Vietnamese meaning: \(word.meaningVi)"))

                    Divider().padding(.vertical, Spacing.xs)

                    Eyebrow(text: "Example")
                    Text(Self.highlight(word.term, in: word.example))
                        .font(Typography.body)
                        .foregroundStyle(Color.ink)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, Spacing.l)
                .padding(.top, Spacing.xl + 4)
                .padding(.bottom, Spacing.xl)
                .cardSurface(accent: .primarySoft)
            }
        } action: {
            PrimaryButton(title: isLast ? "Start practice" : "Next word") {
                motion.perform(MotionTokens.transition) { store.finishLearning() }
            }
        }
    }

    static func highlight(_ term: String, in sentence: String) -> AttributedString {
        var attributed = AttributedString(sentence)
        if let range = attributed.range(of: term, options: .caseInsensitive) {
            attributed[range].inlinePresentationIntent = .stronglyEmphasized
            attributed[range].foregroundColor = Color.primarySoftInk
        }
        return attributed
    }
}
