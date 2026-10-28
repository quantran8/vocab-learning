import SwiftUI

/// Tap a word and a meaning (either order). Only correct pairs lock in green. A wrong pair turns
/// both picks red and shakes them once, then they return to normal.
struct MatchingPairsView: View {
    let run: TemplateRun
    @Environment(TemplateSandboxStore.self) private var sandbox
    @Environment(\.motion) private var motion
    @State private var selectedWordID: String?
    @State private var selectedGlossID: String?
    @State private var wrongPair: WrongPair?
    /// Only ever increases, so clearing the red state never replays the shake.
    @State private var shakeCount: CGFloat = 0
    /// Tallest tile face seen so far; every tile uses it so both columns line up.
    @State private var tileHeight: CGFloat = Spacing.tileMinHeight

    private struct WrongPair: Equatable {
        let wordID: String
        let glossID: String
        let token = UUID()
    }

    var body: some View {
        let glosses = DemoSeed.shuffled(run.pairWords, seed: DemoSeed.defaultSeed)

        TemplateFrame(run: run) {
            HStack(alignment: .top, spacing: Spacing.s) {
                column(title: "English") {
                    ForEach(run.pairWords) { word in
                        pairTile(word.term, id: word.id, isGloss: false)
                    }
                }
                column(title: "Tiếng Việt") {
                    ForEach(glosses) { word in
                        pairTile(word.meaningVi, id: word.id, isGloss: true)
                    }
                }
            }
        } action: {
            TemplateActionBar(
                run: run,
                requirement: "\(run.matchedWordIDs.count) of \(run.pairWords.count) pairs matched"
            )
        }
    }

    private func column<Content: View>(title: LocalizedStringKey, @ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: Spacing.s) {
            Eyebrow(text: title)
            content()
        }
        .frame(maxWidth: .infinity)
    }

    private func pairTile(_ text: String, id: String, isGloss: Bool) -> some View {
        let isMatched = run.matchedWordIDs.contains(id)
        let isSelected = (isGloss ? selectedGlossID : selectedWordID) == id
        let isWrong = wrongPair.map { (isGloss ? $0.glossID : $0.wordID) == id } ?? false
        let state: WordTileVisualState = isMatched ? .correct : (isWrong ? .incorrect : (isSelected ? .selected : .idle))

        return Button {
            pick(id, isGloss: isGloss)
        } label: {
            WordTile(text: text, visualState: state, minHeight: tileHeight)
                .onGeometryChange(for: CGFloat.self) { proxy in
                    proxy.size.height - Spacing.tileDepth
                } action: { face in
                    if face > tileHeight { tileHeight = face }
                }
                .modifier(ShakeEffect(travel: isWrong && !motion.reduceMotion ? 6 : 0, animatableData: shakeCount))
        }
        .buttonStyle(.plain)
        .disabled(isMatched || run.phase.isFinished)
        .accessibilityLabel(Text(isGloss ? "\(text), meaning" : "\(text), English word"))
        .accessibilityValue(isMatched ? Text("Matched") : (isWrong ? Text("Not a pair") : (isSelected ? Text("Selected") : Text(verbatim: ""))))
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    private func pick(_ id: String, isGloss: Bool) {
        wrongPair = nil
        if isGloss {
            selectedGlossID = selectedGlossID == id ? nil : id
        } else {
            selectedWordID = selectedWordID == id ? nil : id
        }
        guard let wordID = selectedWordID, let glossID = selectedGlossID else {
            sandbox.haptics.selectionChanged()
            return
        }
        sandbox.selectPair(wordID: wordID, glossWordID: glossID)
        selectedWordID = nil
        selectedGlossID = nil

        guard sandbox.run?.matchedWordIDs.contains(wordID) != true else { return }
        let pair = WrongPair(wordID: wordID, glossID: glossID)
        // Red + one shake, then back to normal. Purely visual; the token ignores stale completions.
        withAnimation(motion.travel(.linear(duration: 0.4)) ?? MotionTokens.reducedCrossfade) {
            wrongPair = pair
            shakeCount += 1
        } completion: {
            guard wrongPair?.token == pair.token else { return }
            withAnimation(motion.animation(MotionTokens.feedback)) { wrongPair = nil }
        }
    }
}
