import SwiftUI

/// Build stage content. Header and the Check/Continue action live in `SessionFlowView`.
struct BuildView: View {
    let index: Int
    @Environment(SessionStore.self) private var store
    @Environment(FlowDraft.self) private var draft

    var body: some View {
        if let challenge = store.buildChallenge(at: index) {
            content(challenge)
        }
    }

    private func content(_ challenge: BuildChallenge) -> some View {
        @Bindable var draft = draft
        let completed = store.isBuildCompleted(index: index)

        return VStack(spacing: Spacing.l) {
            StageIntro(
                number: 2,
                label: "Build the sentence",
                title: challenge.context,
                subtitle: "Pick the word that fits naturally.",
                systemImage: "square.stack.3d.up.fill"
            )

            WordStackBoard(
                prompt: challenge.prompt,
                options: challenge.options,
                // Once solved, the answer is pinned in the slot. The draft is cleared on Continue while
                // this view is still sliding out, and must not pull the tile back to the bank.
                placedTileID: completed ? .constant(challenge.acceptedOptionIDs.first) : $draft.selectedTileID,
                correctTileID: completed ? challenge.acceptedOptionIDs.first : nil,
                incorrectTileID: incorrectTileID,
                isLocked: incorrectTileID != nil,
                isDragging: $draft.isDragging,
                haptics: store.haptics
            )
        }
    }

    private var incorrectTileID: String? {
        if case .buildIncorrect(let tileID) = store.state.feedback { return tileID }
        return nil
    }
}
