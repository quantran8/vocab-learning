import SwiftUI

/// Large answer card used by the choice tasks.
struct ChoiceTileButton: View {
    let text: String
    let state: WordTileVisualState
    let action: () -> Void
    @Environment(\.motion) private var motion
    @State private var bounce = 0

    var body: some View {
        Button {
            if !motion.reduceMotion { bounce += 1 }
            action()
        } label: {
            EmptyView()
        }
        // A quick tap inside a ScrollView often never reports isPressed, so the tile also sinks on tap.
        .buttonStyle(ChoiceTilePressStyle(text: text, state: state, bounce: bounce))
        .disabled(state == .disabled || state == .correct)
        .accessibilityLabel(Text("\(text), option"))
        .accessibilityValue(choiceValue)
        .accessibilityAddTraits(state == .selected ? [.isSelected] : [])
    }

    private var choiceValue: Text {
        switch state {
        case .selected: Text("Selected")
        case .correct: Text("Correct")
        case .incorrect: Text("Incorrect, already checked")
        case .disabled: Text("Unavailable")
        default: Text(verbatim: "")
        }
    }
}

/// Drives the tile's own pressed face while a finger is down on an idle or selected tile.
private struct ChoiceTilePressStyle: ButtonStyle {
    let text: String
    let state: WordTileVisualState
    let bounce: Int

    func makeBody(configuration: Configuration) -> some View {
        let canPress = state == .idle || state == .selected
        WordTile(text: text, visualState: configuration.isPressed && canPress ? .pressed : state, bounceTrigger: bounce, font: Typography.choice)
    }
}
