import SwiftUI

struct RecallInput: View {
    @Binding var text: String
    var isFocused: FocusState<Bool>.Binding
    let isEnabled: Bool
    let onSubmit: () -> Void

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: Radii.tile, style: .continuous)
        VStack(alignment: .leading, spacing: Spacing.s) {
            Text("Your answer")
                .font(Typography.micro.weight(.bold))
                .foregroundStyle(Color.mutedInk)
            TextField("Type the English word…", text: $text)
                .font(Typography.tile)
                .foregroundStyle(Color.ink)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .keyboardType(.asciiCapable)
                .submitLabel(.done)
                .focused(isFocused)
                .onSubmit(onSubmit)
                .disabled(!isEnabled)
                .padding(.horizontal, Spacing.l - 4)
                .frame(minHeight: Spacing.tileMinHeight)
                .background(Color.surface, in: shape)
                .overlay(shape.strokeBorder(isFocused.wrappedValue ? Color.focusRing : Color.stroke, lineWidth: 2))
                .accessibilityLabel(Text("Your answer"))
        }
    }
}
