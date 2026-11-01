import SwiftUI

/// Large answer card used by the choice tasks.
struct ChoiceTileButton: View {
    let text: String
    let state: WordTileVisualState
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            EmptyView()
        }
        .buttonStyle(ChoiceTilePressStyle(text: text, state: state))
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

/// Drives the tile's own pressed face (drop + scale) while a finger is down on an idle or selected tile.
private struct ChoiceTilePressStyle: ButtonStyle {
    let text: String
    let state: WordTileVisualState

    func makeBody(configuration: Configuration) -> some View {
        let canPress = state == .idle || state == .selected
        WordTile(text: text, visualState: configuration.isPressed && canPress ? .pressed : state)
    }
}
