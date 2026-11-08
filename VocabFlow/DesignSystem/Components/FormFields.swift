import SwiftUI

/// A titled text input in a bordered tile, used by the account forms.
struct LabeledField<Content: View>: View {
    let title: LocalizedStringKey
    @ViewBuilder let content: Content

    init(_ title: LocalizedStringKey, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: Radii.tile, style: .continuous)
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(title)
                .font(Typography.secondary.weight(.semibold))
                .foregroundStyle(Color.ink)
            content
                .font(Typography.body)
                .foregroundStyle(Color.ink)
                .padding(.horizontal, Spacing.m)
                .frame(minHeight: Spacing.tileMinHeight)
                .background(Color.surface, in: shape)
                .overlay(shape.strokeBorder(Color.stroke, lineWidth: 1.5))
        }
    }
}

/// A password input with a show/hide toggle. Focus stays on the field when it flips.
struct PasswordInput<Field: Hashable>: View {
    let placeholder: LocalizedStringKey
    @Binding var text: String
    let contentType: UITextContentType
    let focus: FocusState<Field?>.Binding
    let field: Field
    var submitLabel: SubmitLabel = .go
    var onSubmit: () -> Void = {}

    @State private var isVisible = false

    var body: some View {
        HStack(spacing: Spacing.xs) {
            Group {
                if isVisible {
                    TextField(placeholder, text: $text)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                } else {
                    SecureField(placeholder, text: $text)
                }
            }
            .textContentType(contentType)
            .submitLabel(submitLabel)
            .focused(focus, equals: field)
            .onSubmit(onSubmit)

            Button {
                let wasFocused = focus.wrappedValue == field
                isVisible.toggle()
                // Swapping the field drops focus; keep the keyboard up.
                if wasFocused { focus.wrappedValue = field }
            } label: {
                Image(systemName: isVisible ? "eye.slash" : "eye")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Color.mutedInk)
                    .frame(width: Spacing.minTouchTarget, height: Spacing.minTouchTarget)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.trailing, -Spacing.s)
            .accessibilityLabel(isVisible ? Text("Hide password") : Text("Show password"))
        }
    }
}
