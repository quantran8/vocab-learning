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
                .font(Typography.secondary.weight(.semibold))
                .foregroundStyle(Color.ink)
            TextField("Type the English word", text: $text)
                .font(Typography.body)
                .foregroundStyle(Color.ink)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .keyboardType(.asciiCapable)
                .submitLabel(.done)
                .focused(isFocused)
                .onSubmit(onSubmit)
                .disabled(!isEnabled)
                .padding(.horizontal, Spacing.m + 2)
                .frame(minHeight: Spacing.tileMinHeight + 6)
                .background(Color.surface, in: shape)
                .overlay(shape.strokeBorder(isFocused.wrappedValue ? Color.focusRing : Color.stroke,
                                            lineWidth: isFocused.wrappedValue ? 2 : 1))
                .accessibilityLabel(Text("Your answer"))
        }
    }
}
