import SwiftUI

/// Word Stack, including the `fillBlank` and `phrase` variants (same board and evaluator).
struct WordStackView: View {
    let run: TemplateRun
    @Environment(TemplateSandboxStore.self) private var sandbox
    @Environment(\.motion) private var motion
    @State private var placedTileID: String?
    @State private var isDragging = false

    var body: some View {
        TemplateFrame(run: run, instruction: instruction, isScrollDisabled: isDragging) {
            VStack(spacing: Spacing.l) {
                if let context = run.exercise.context {
                    ContextNote(text: context)
                }
                SandboxStackBoard(run: run, placedTileID: $placedTileID, isDragging: $isDragging)
            }
        } action: {
            TemplateActionBar(
                run: run,
                canCheck: placedTileID != nil && placedTileID != run.incorrectChoiceID,
                onCheck: {
                    guard let placedTileID else { return }
                    sandbox.submitChoice(placedTileID)
                }
            )
        }
        .onChange(of: sandbox.attemptToken) {
            withAnimation(motion.travel(MotionTokens.returnToOrigin)) { placedTileID = nil }
        }
    }

    private var instruction: LocalizedStringKey {
        switch run.exercise.variant {
        case .fillBlank: "Fill in the missing word."
        case .phrase: "Snap the missing word into the phrase."
        default: "Complete the sentence."
        }
    }
}
