import SwiftUI

/// Sheet adding any word to the learning path: type it, review what the backend found, confirm.
struct AddWordView: View {
    @Environment(CustomWordStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var text = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.m) {
                HStack {
                    Eyebrow(text: "Add a word")
                    Spacer()
                    SheetCloseButton()
                }
                content
            }
            .padding(.horizontal, Spacing.screenGutter)
            .padding(.top, Spacing.l)
            .padding(.bottom, Spacing.l)
        }
        .scrollDismissesKeyboard(.interactively)
        .onDisappear { store.resetLookup() }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .presentationBackground(Color.canvas)
    }

    @ViewBuilder
    private var content: some View {
        switch store.phase {
        case .idle:
            WordEntry(text: $text, message: nil)
        case .loading:
            LookupProgress()
        case .failed(let message, let canRetry):
            WordEntry(text: $text, message: message)
            if canRetry {
                SecondaryButton(title: "Try again", systemImage: "arrow.clockwise") {
                    Task { await store.retryLookup() }
                }
            }
        case .result(let result):
            lookupResult(result)
            noticeText
            SecondaryButton(title: "Try another word") { store.resetLookup() }
        case .added(let lemma, let isNew):
            AddedConfirmation(lemma: lemma, isNew: isNew) {
                text = ""
                store.resetLookup()
            } onDone: {
                dismiss()
            }
        }
    }

    @ViewBuilder
    private func lookupResult(_ result: CustomWordLookup) -> some View {
        switch result {
        case .existing(let word):
            ExistingWordView(word: word)
        case .draft(let draft):
            DraftPreview(draft: draft, isPrivate: false)
                .id(draft.draftId)
        case .newMeaningDraft(let draft):
            DraftPreview(draft: draft, isPrivate: true)
                .id(draft.draftId)
        case .invalid:
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text("That doesn’t look like a word")
                    .font(Typography.screenTitle)
                    .foregroundStyle(Color.ink)
                    .accessibilityAddTraits(.isHeader)
                Text("Check the spelling, or try another word.")
                    .font(Typography.secondary)
                    .foregroundStyle(Color.mutedInk)
            }
        }
    }

    @ViewBuilder
    private var noticeText: some View {
        if let notice = store.notice {
            Text(verbatim: notice)
                .font(Typography.secondary)
                .foregroundStyle(Color.errorInk)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct WordEntry: View {
    @Binding var text: String
    let message: String?
    @Environment(CustomWordStore.self) private var store
    @FocusState private var isFocused: Bool

    var body: some View {
        let issue = CustomWordInput.issue(in: text)
        VStack(alignment: .leading, spacing: Spacing.m) {
            ExerciseHeading("Which word do you want to learn?", subtitle: "We’ll find it or prepare it for you.")

            TextField("Type an English word", text: $text)
                .font(Typography.body)
                .foregroundStyle(Color.ink)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.search)
                .focused($isFocused)
                .onSubmit { search() }
                .padding(.horizontal, Spacing.m - 2)
                .frame(minHeight: Spacing.minTouchTarget + 4)
                .background(Color.surface, in: entryShape)
                .overlay(entryShape.strokeBorder(isFocused ? Color.focusRing : Color.stroke, lineWidth: isFocused ? 2 : 1.5))

            if let hint = hint(for: issue) {
                Text(hint)
                    .font(Typography.micro)
                    .foregroundStyle(Color.errorInk)
            }
            if let message {
                Text(verbatim: message)
                    .font(Typography.secondary)
                    .foregroundStyle(Color.errorInk)
                    .fixedSize(horizontal: false, vertical: true)
            }

            PrimaryButton(title: "Look up", isEnabled: issue == nil) { search() }
        }
        .onAppear { isFocused = true }
    }

    private var entryShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: Radii.tile, style: .continuous)
    }

    private func hint(for issue: CustomWordInput.Issue?) -> LocalizedStringKey? {
        switch issue {
        case nil, .empty: nil
        case .tooLong: "Keep it under \(CustomWordInput.maxTextLength) characters."
        case .invalidCharacters: "Use letters, spaces, hyphens and apostrophes, starting with a letter."
        }
    }

    private func search() {
        guard CustomWordInput.issue(in: text) == nil else { return }
        Task { await store.lookup(text) }
    }
}

private struct LookupProgress: View {
    var body: some View {
        VStack(spacing: Spacing.s) {
            ProgressView()
                .controlSize(.large)
            Text("Looking up your word…")
                .font(Typography.emphasis)
                .foregroundStyle(Color.ink)
            Text("New words can take up to a minute.")
                .font(Typography.secondary)
                .foregroundStyle(Color.mutedInk)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.xl)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Existing word

private struct ExistingWordView: View {
    let word: ExistingWord
    @Environment(CustomWordStore.self) private var store
    @State private var isAskingContext = false
    @State private var isEditing = false
    @State private var selectedID: String?
    /// One editable copy per meaning the learner can still add.
    @State private var drafts: [String: CustomWordEditDraft]

    init(word: ExistingWord) {
        self.word = word
        let addable = word.meanings.filter { !$0.inRoadmap && $0.addition != nil }
        _selectedID = State(initialValue: addable.first?.id)
        _drafts = State(initialValue: Dictionary(uniqueKeysWithValues: addable.map {
            ($0.id, CustomWordEditDraft(lemma: word.lemma, meaning: $0))
        }))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            Text(verbatim: word.lemma)
                .font(Typography.display)
                .foregroundStyle(Color.ink)
                .accessibilityAddTraits(.isHeader)

            ForEach(word.meanings) { meaning in
                if let draft = drafts[meaning.id] {
                    Button {
                        selectedID = meaning.id
                    } label: {
                        SenseCard(
                            caption: meaning.partOfSpeech,
                            edited: draft,
                            isSelected: meaning.id == selectedID,
                            isAITranslated: meaning.status == .translationDraft
                        )
                    }
                    .buttonStyle(PressScaleButtonStyle())
                    .accessibilityAddTraits(meaning.id == selectedID ? .isSelected : [])
                } else {
                    ClosedMeaningRow(meaning: meaning)
                }
            }

            if let selectedID, let meaning = word.meanings.first(where: { $0.id == selectedID }) {
                SecondaryButton(title: "Edit this meaning", systemImage: "pencil") { isEditing = true }
                PrimaryButton(title: "Add to my path", isEnabled: !store.isAdding) { add(meaning) }
            }

            if isAskingContext {
                ContextPrompt(lemma: word.lemma)
            } else {
                Button("The meaning I need isn’t here") { isAskingContext = true }
                    .font(Typography.emphasis)
                    .foregroundStyle(Color.selectedInk)
                    .frame(minHeight: Spacing.minTouchTarget)
            }
        }
        .sheet(isPresented: $isEditing) {
            if let selectedID, let draft = drafts[selectedID] {
                CustomWordEditView(initial: draft) { edited in
                    drafts[selectedID] = edited
                    isEditing = false
                }
            }
        }
    }

    private func add(_ meaning: ExistingMeaning) {
        guard var addition = meaning.addition else { return }
        addition.edits = drafts[meaning.id]?.edits
        Task { await store.add(addition, lemma: word.lemma) }
    }
}

/// A meaning that can't be picked: already on the path, or not available.
private struct ClosedMeaningRow: View {
    let meaning: ExistingMeaning

    var body: some View {
        HStack(alignment: .top, spacing: Spacing.s) {
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(verbatim: meaning.partOfSpeech)
                    .font(Typography.micro)
                    .foregroundStyle(Color.mutedInk)
                if meaning.status == .unavailable {
                    Text("Not available right now")
                        .font(Typography.emphasis)
                        .foregroundStyle(Color.disabledInk)
                }
                if let text = meaning.meaningText {
                    Text(verbatim: text)
                        .font(Typography.emphasis)
                        .foregroundStyle(Color.ink)
                }
                if let definition = meaning.definitionText {
                    Text(verbatim: definition)
                        .font(Typography.secondary)
                        .foregroundStyle(Color.mutedInk)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 0)
            if meaning.inRoadmap {
                Chip(text: "On your path", fill: .successSurface, foreground: .successInk)
            }
        }
        .padding(Spacing.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardSurface(radius: Radii.card - 2, fill: meaning.status == .unavailable ? .disabledSurface : .surface)
    }
}

private struct ContextPrompt: View {
    let lemma: String
    @Environment(CustomWordStore.self) private var store
    @State private var context = ""

    private var isValid: Bool {
        (1...CustomWordInput.maxContextLength).contains(context.trimmed.utf16.count)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            EditorField(title: "Describe the meaning you need", text: $context, maxLength: CustomWordInput.maxContextLength)
            Text("We’ll create this meaning with AI. It stays private to you.")
                .font(Typography.micro)
                .foregroundStyle(Color.mutedInk)
                .fixedSize(horizontal: false, vertical: true)
            // The lemma, not the typed form: context only applies to a word the backend already has.
            PrimaryButton(title: "Find this meaning", isEnabled: isValid) {
                Task { await store.lookup(lemma, context: context) }
            }
        }
        .padding(.top, Spacing.xs)
    }
}

// MARK: - Draft

private struct DraftPreview: View {
    let draft: WordDraft
    let isPrivate: Bool
    @Environment(CustomWordStore.self) private var store
    @State private var selected = 0
    @State private var isEditing = false
    @State private var senses: [CustomWordEditDraft]

    init(draft: WordDraft, isPrivate: Bool) {
        self.draft = draft
        self.isPrivate = isPrivate
        _senses = State(initialValue: draft.senses.map { CustomWordEditDraft(lemma: draft.lemma, sense: $0) })
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            HStack {
                Text(verbatim: draft.lemma)
                    .font(Typography.display)
                    .foregroundStyle(Color.ink)
                    .accessibilityAddTraits(.isHeader)
                Spacer(minLength: Spacing.xs)
                Chip(text: "AI-generated", fill: .selectedSurface, foreground: .selectedInk)
            }

            Text(isPrivate ? "This new meaning is private to you." : "Created by AI, so give it a quick check.")
                .font(Typography.secondary)
                .foregroundStyle(Color.mutedInk)
                .fixedSize(horizontal: false, vertical: true)

            ForEach(Array(draft.senses.enumerated()), id: \.offset) { index, sense in
                Button {
                    selected = index
                } label: {
                    SenseCard(
                        caption: [sense.partOfSpeech, sense.cefrLevel, sense.ipa].compactMap { $0 }.joined(separator: " · "),
                        edited: senses[index],
                        isSelected: index == selected
                    )
                }
                .buttonStyle(PressScaleButtonStyle())
                .accessibilityAddTraits(index == selected ? .isSelected : [])
            }

            SecondaryButton(title: "Edit this meaning", systemImage: "pencil") { isEditing = true }
            PrimaryButton(title: "Add to my path", isEnabled: !store.isAdding && senses.indices.contains(selected)) {
                let addition = CustomWordAddition.draft(draft.draftId, senseIndex: selected, edits: senses[selected].edits)
                Task { await store.add(addition, lemma: draft.lemma) }
            }
        }
        .sheet(isPresented: $isEditing) {
            CustomWordEditView(initial: senses[selected]) { edited in
                senses[selected] = edited
                isEditing = false
            }
        }
    }
}

private struct SenseCard: View {
    let caption: String
    let edited: CustomWordEditDraft
    let isSelected: Bool
    var isAITranslated = false

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack(spacing: Spacing.xs) {
                Text(verbatim: caption)
                    .font(Typography.micro)
                    .foregroundStyle(Color.mutedInk)
                if isAITranslated {
                    Chip(text: "AI-translated", fill: .neutralSurface, foreground: .mutedInk)
                }
                Spacer(minLength: 0)
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color.interactive)
                        .accessibilityHidden(true)
                }
            }
            Text(verbatim: edited.meaningText)
                .font(Typography.emphasis)
                .foregroundStyle(Color.ink)
            Text(verbatim: edited.definitionText)
                .font(Typography.secondary)
                .foregroundStyle(Color.mutedInk)
            ForEach(edited.examples) { example in
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text(highlightedExample(example.text, at: edited.locator(for: example)))
                        .font(Typography.secondary)
                        .foregroundStyle(Color.ink)
                    Text(verbatim: example.translation)
                        .font(Typography.micro)
                        .foregroundStyle(Color.mutedInk)
                }
                .padding(.top, Spacing.xxs)
            }
        }
        .multilineTextAlignment(.leading)
        .fixedSize(horizontal: false, vertical: true)
        .padding(Spacing.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardSurface(radius: Radii.card - 2, fill: isSelected ? .selectedSurface : .surface)
    }
}

private struct AddedConfirmation: View {
    let lemma: String
    let isNew: Bool
    let onAddAnother: () -> Void
    let onDone: () -> Void

    var body: some View {
        VStack(spacing: Spacing.m) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 44, weight: .semibold))
                .foregroundStyle(Color.success)
                .accessibilityHidden(true)
            Text(isNew ? "“\(lemma)” is on your learning path" : "“\(lemma)” was already on your learning path")
                .font(Typography.screenTitle)
                .foregroundStyle(Color.ink)
                .multilineTextAlignment(.center)
            Text("It will show up in your next sessions.")
                .font(Typography.secondary)
                .foregroundStyle(Color.mutedInk)
            PrimaryButton(title: "Done", action: onDone)
            SecondaryButton(title: "Add another word", action: onAddAnother)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, Spacing.l)
    }
}
