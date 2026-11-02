import SwiftUI

/// Sheet editing the learner's own copy of a word. The word itself, its IPA and level stay fixed.
/// Dismissing discards the changes.
struct CustomWordEditView: View {
    let onSave: (CustomWordEditDraft) -> Void
    private let initial: CustomWordEditDraft
    @State private var draft: CustomWordEditDraft

    init(initial: CustomWordEditDraft, onSave: @escaping (CustomWordEditDraft) -> Void) {
        self.initial = initial
        self.onSave = onSave
        _draft = State(initialValue: initial)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.m) {
                HStack {
                    Eyebrow(text: "Edit word")
                    Spacer()
                    SheetCloseButton()
                }

                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text(verbatim: draft.lemma)
                        .font(Typography.display)
                        .foregroundStyle(Color.ink)
                        .accessibilityAddTraits(.isHeader)
                    Text("Your changes apply only to you. Other learners keep the original.")
                        .font(Typography.secondary)
                        .foregroundStyle(Color.mutedInk)
                        .fixedSize(horizontal: false, vertical: true)
                }

                CustomWordEditFields(draft: $draft)
            }
            .padding(.horizontal, Spacing.screenGutter)
            .padding(.top, Spacing.l)
            .padding(.bottom, Spacing.l)
        }
        .scrollDismissesKeyboard(.interactively)
        .safeAreaInset(edge: .bottom) {
            PinnedActionBar {
                PrimaryButton(
                    title: "Save",
                    requirement: "Change something and fill in every field",
                    isEnabled: draft.isValid && draft != initial
                ) {
                    onSave(draft)
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .presentationBackground(Color.canvas)
    }
}

/// The editable text of a word: meaning, definition and each example.
struct CustomWordEditFields: View {
    @Binding var draft: CustomWordEditDraft

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            EditorField(title: "Meaning", text: $draft.meaningText, maxLength: CustomWordInput.maxFieldLength)
            EditorField(title: "Definition", text: $draft.definitionText, maxLength: CustomWordInput.maxFieldLength)

            ForEach($draft.examples) { $example in
                VStack(alignment: .leading, spacing: Spacing.m) {
                    EditorField(title: "Example", text: $example.text, maxLength: CustomWordInput.maxFieldLength)
                    if example.isRewritten, !example.text.trimmed.isEmpty {
                        HighlightPicker(
                            sentence: example.text.trimmed,
                            selection: draft.locator(for: example)
                        ) { word in
                            draft.pick(word, inExample: example.id)
                        }
                    }
                    EditorField(title: "Translation", text: $example.translation, maxLength: CustomWordInput.maxFieldLength)
                }
            }
        }
    }
}

/// The words of a rewritten sentence, for choosing which ones to highlight. A tappable word list
/// rather than text selection, which `TextField` can't report before iOS 18.
private struct HighlightPicker: View {
    let sentence: String
    let selection: TargetLocator?
    let onPick: (TargetLocator) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(selection == nil ? "Tap the word to highlight." : "Highlighted word. Tap to change it.")
                .font(Typography.micro)
                .foregroundStyle(selection == nil ? Color.errorInk : Color.mutedInk)
            FlowLayout(spacing: Spacing.xxs, lineSpacing: Spacing.xxs, alignment: .leading) {
                ForEach(TargetLocator.words(in: sentence), id: \.start) { word in
                    wordButton(word)
                }
            }
        }
    }

    private func wordButton(_ word: TargetLocator) -> some View {
        let isSelected = selection?.contains(word) ?? false
        return Button {
            onPick(word)
        } label: {
            Text(verbatim: word.substring(of: sentence) ?? "")
                .font(Typography.secondary)
                .foregroundStyle(isSelected ? Color.selectedInk : Color.ink)
                .padding(.horizontal, Spacing.xs)
                .frame(minHeight: Spacing.minTouchTarget)
                .background(
                    isSelected ? Color.selectedSurface : Color.neutralSurface,
                    in: RoundedRectangle(cornerRadius: Radii.chip, style: .continuous)
                )
        }
        .buttonStyle(PressScaleButtonStyle())
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

/// Multi-line labelled text field with the app's outlined look.
struct EditorField: View {
    let title: LocalizedStringKey
    @Binding var text: String
    var maxLength: Int?
    var lines: ClosedRange<Int> = 1...5
    var focusesOnAppear = false
    @FocusState private var isFocused: Bool

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: Radii.tile, style: .continuous)
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Eyebrow(text: title, color: isFocused ? .selectedInk : .mutedInk)
                .accessibilityHidden(true)
            TextField(title, text: $text, axis: .vertical)
                .font(Typography.body)
                .foregroundStyle(Color.ink)
                .lineLimit(lines)
                .focused($isFocused)
                .onAppear { if focusesOnAppear { isFocused = true } }
                .padding(.horizontal, Spacing.m - 2)
                .padding(.vertical, Spacing.s)
                .frame(minHeight: Spacing.minTouchTarget + 4)
                .background(Color.surface, in: shape)
                .overlay(shape.strokeBorder(isFocused ? Color.focusRing : Color.stroke, lineWidth: isFocused ? 2 : 1.5))
            if let maxLength, text.utf16.count > maxLength {
                Text("Keep this under \(maxLength) characters.")
                    .font(Typography.micro)
                    .foregroundStyle(Color.errorInk)
            }
        }
    }
}

/// Sentence with its target word emphasized, placed by the backend's locator rather than by search.
func highlightedExample(_ sentence: String, at locator: TargetLocator?) -> AttributedString {
    var attributed = AttributedString(sentence)
    if let range = locator?.nsRange(in: sentence).flatMap({ Range<AttributedString.Index>($0, in: attributed) }) {
        attributed[range].inlinePresentationIntent = .stronglyEmphasized
        attributed[range].foregroundColor = Color.selectedInk
    }
    return attributed
}
