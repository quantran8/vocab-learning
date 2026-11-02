import SwiftUI

/// Sheet adding any word to the learning path: type it, review what the backend found, confirm.
struct AddWordView: View {
    @Environment(CustomWordStore.self) private var store
    @Environment(SpeechPlayer.self) private var speech
    @Environment(\.dismiss) private var dismiss
    @State private var text = ""

    var body: some View {
        // The ZStack ties onDisappear to the sheet, not to each phase's view.
        ZStack { content }
            .onDisappear {
                store.resetLookup()
                speech.stop()
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
            .presentationBackground(Color.canvas)
    }

    @ViewBuilder
    private var content: some View {
        switch store.phase {
        case .idle:
            WordEntry(text: $text, message: nil, canRetry: false)
        case .loading:
            AddWordScaffold { LookupProgress() }
        case .failed(let message, let canRetry):
            if let word = store.baseWord {
                OtherMeaningStage(
                    lemma: word.lemma,
                    context: store.lastContext,
                    message: message,
                    canRetry: canRetry,
                    onBack: store.goBack
                )
            } else {
                WordEntry(text: $text, message: message, canRetry: canRetry)
            }
        case .result(let result):
            lookupResult(result)
        case .added(let lemma, let isNew, let ipa):
            AddedConfirmation(lemma: lemma, ipa: ipa, isNew: isNew) { dismiss() }
        }
    }

    @ViewBuilder
    private func lookupResult(_ result: CustomWordLookup) -> some View {
        switch result {
        case .existing(let word):
            WordReview(
                lemma: word.lemma,
                senses: ReviewSense.senses(of: word),
                closed: word.meanings.filter { !$0.canBeAdded },
                search: .otherMeaning
            )
            .id(word.meanings.map(\.id))
        case .draft(let draft):
            WordReview(lemma: draft.lemma, senses: ReviewSense.senses(of: draft, tag: "AI-generated"))
                .id(draft.draftId)
        case .newMeaningDraft(let draft):
            WordReview(lemma: draft.lemma, senses: ReviewSense.senses(of: draft, tag: "Private to you"), search: .searchAgain)
                .id(draft.draftId)
        case .invalid:
            AddWordScaffold(onBack: store.goBack) {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text("That doesn’t look like a word")
                        .font(Typography.screenTitle)
                        .foregroundStyle(Color.ink)
                        .accessibilityAddTraits(.isHeader)
                    Text("Check the spelling, or try another word.")
                        .font(Typography.secondary)
                        .foregroundStyle(Color.mutedInk)
                }
            } bar: {
                PinnedActionBar {
                    PrimaryButton(title: "Try another word") { store.resetLookup() }
                }
            }
        }
    }
}

/// One step of the sheet: a header, scrolling content, and an action bar pinned to the bottom.
private struct AddWordScaffold<Content: View, Bar: View>: View {
    var eyebrow: LocalizedStringKey?
    var onBack: (() -> Void)?
    @ViewBuilder let content: Content
    @ViewBuilder let bar: Bar

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.l) {
                HStack {
                    if let onBack {
                        SheetBackButton(action: onBack)
                    } else if let eyebrow {
                        Eyebrow(text: eyebrow)
                    }
                    Spacer()
                    SheetCloseButton()
                }
                content
            }
            .padding(.horizontal, Spacing.screenGutter)
            .padding(.top, Spacing.m)
            .padding(.bottom, Spacing.l)
        }
        .scrollDismissesKeyboard(.interactively)
        .safeAreaInset(edge: .bottom) { bar }
    }
}

extension AddWordScaffold where Bar == EmptyView {
    init(eyebrow: LocalizedStringKey? = nil, onBack: (() -> Void)? = nil, @ViewBuilder content: () -> Content) {
        self.init(eyebrow: eyebrow, onBack: onBack, content: content, bar: { EmptyView() })
    }
}

private struct WordEntry: View {
    @Binding var text: String
    let message: String?
    let canRetry: Bool
    @Environment(CustomWordStore.self) private var store
    @FocusState private var isFocused: Bool

    var body: some View {
        let issue = CustomWordInput.issue(in: text)
        AddWordScaffold(eyebrow: "Add a word") {
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
                    ErrorText(message: message)
                }
                if canRetry {
                    SecondaryButton(title: "Try again", systemImage: "arrow.clockwise") {
                        Task { await store.retryLookup() }
                    }
                }
            }
        } bar: {
            PinnedActionBar {
                PrimaryButton(title: "Look up", isEnabled: issue == nil) { search() }
            }
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

private struct ErrorText: View {
    let message: String

    var body: some View {
        Text(verbatim: message)
            .font(Typography.secondary)
            .foregroundStyle(Color.errorInk)
            .fixedSize(horizontal: false, vertical: true)
    }
}

// MARK: - Review

/// A meaning the learner can add, whichever lookup result it came from.
private struct ReviewSense: Identifiable {
    let id: String
    let partOfSpeech: String
    let ipa: String?
    let tag: LocalizedStringKey?
    let addition: CustomWordAddition
    let draft: CustomWordEditDraft

    static func senses(of word: ExistingWord) -> [ReviewSense] {
        word.meanings.compactMap { meaning in
            guard meaning.canBeAdded, let addition = meaning.addition else { return nil }
            return ReviewSense(
                id: meaning.id,
                partOfSpeech: meaning.partOfSpeech,
                ipa: nil,
                tag: meaning.status == .translationDraft ? "AI-translated" : nil,
                addition: addition,
                draft: CustomWordEditDraft(lemma: word.lemma, meaning: meaning)
            )
        }
    }

    static func senses(of draft: WordDraft, tag: LocalizedStringKey) -> [ReviewSense] {
        draft.senses.enumerated().map { index, sense in
            ReviewSense(
                id: String(index),
                partOfSpeech: sense.partOfSpeech,
                ipa: sense.ipa,
                tag: tag,
                addition: .draft(draft.draftId, senseIndex: index, edits: nil),
                draft: CustomWordEditDraft(lemma: draft.lemma, sense: sense)
            )
        }
    }
}

private struct WordReview: View {
    /// The way to another meaning. Context only works on a word the backend already has,
    /// so a brand-new word offers none.
    enum Search {
        case otherMeaning, searchAgain
    }

    private enum Stage {
        case details, edit, otherMeaning
    }

    let lemma: String
    let senses: [ReviewSense]
    let closed: [ExistingMeaning]
    let search: Search?
    @Environment(CustomWordStore.self) private var store
    @State private var stage = Stage.details
    @State private var selectedID: String?
    /// One editable copy per meaning, so switching between them keeps the changes.
    @State private var drafts: [String: CustomWordEditDraft]

    init(lemma: String, senses: [ReviewSense], closed: [ExistingMeaning] = [], search: Search? = nil) {
        self.lemma = lemma
        self.senses = senses
        self.closed = closed
        self.search = search
        _selectedID = State(initialValue: senses.first?.id)
        _drafts = State(initialValue: Dictionary(uniqueKeysWithValues: senses.map { ($0.id, $0.draft) }))
    }

    private var selected: ReviewSense? {
        senses.first { $0.id == selectedID }
    }

    var body: some View {
        switch stage {
        case .details:
            details
        case .edit:
            if let selected, let draft = drafts[selected.id] {
                EditStage(ipa: selected.ipa, initial: draft) {
                    stage = .details
                } onSave: { edited in
                    drafts[selected.id] = edited
                    stage = .details
                }
            }
        case .otherMeaning:
            OtherMeaningStage(
                lemma: lemma,
                context: search == .searchAgain ? store.lastContext : "",
                message: nil,
                canRetry: false
            ) {
                stage = .details
            }
        }
    }

    private var details: some View {
        AddWordScaffold(onBack: store.goBack) {
            WordHero(lemma: lemma, ipa: selected?.ipa)

            if senses.count > 1 {
                sensePicker
            }
            if let selected, let draft = drafts[selected.id] {
                SenseDetails(draft: draft, tag: selected.tag)
            }

            HStack(spacing: Spacing.s) {
                if selected != nil {
                    SecondaryButton(title: "Edit", systemImage: "pencil") { stage = .edit }
                }
                switch search {
                case .otherMeaning:
                    SecondaryButton(title: "Other meaning", systemImage: "plus") { stage = .otherMeaning }
                case .searchAgain:
                    SecondaryButton(title: "Search again", systemImage: "arrow.clockwise") { stage = .otherMeaning }
                case nil:
                    EmptyView()
                }
            }

            ForEach(closed) { meaning in
                ClosedMeaningRow(meaning: meaning)
            }
        } bar: {
            if selected != nil || store.notice != nil {
                PinnedActionBar {
                    VStack(spacing: Spacing.xs) {
                        if let notice = store.notice {
                            ErrorText(message: notice)
                        }
                        if let selected {
                            PrimaryButton(title: "Add word", isEnabled: !store.isAdding) { add(selected) }
                        }
                    }
                }
            }
        }
    }

    private var sensePicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Spacing.xs) {
                ForEach(senses) { sense in
                    senseButton(sense)
                }
            }
        }
    }

    private func senseButton(_ sense: ReviewSense) -> some View {
        let isSelected = sense.id == selectedID
        return Button {
            selectedID = sense.id
        } label: {
            Text(verbatim: "\(sense.partOfSpeech) · \(drafts[sense.id]?.meaningText ?? "")")
                .font(Typography.secondary.weight(.semibold))
                .foregroundStyle(isSelected ? Color.selectedInk : Color.mutedInk)
                .lineLimit(1)
                .padding(.horizontal, Spacing.s)
                .frame(minHeight: Spacing.minTouchTarget)
                .background(
                    isSelected ? Color.selectedSurface : Color.neutralSurface,
                    in: RoundedRectangle(cornerRadius: Radii.chip, style: .continuous)
                )
        }
        .buttonStyle(PressScaleButtonStyle())
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func add(_ sense: ReviewSense) {
        var addition = sense.addition
        addition.edits = drafts[sense.id]?.edits
        Task { await store.add(addition, lemma: lemma, ipa: sense.ipa) }
    }
}

/// The word, centered, with its IPA and a pronunciation button.
private struct WordHero: View {
    let lemma: String
    let ipa: String?
    @Environment(SpeechPlayer.self) private var speech

    var body: some View {
        VStack(spacing: Spacing.xxs) {
            Text(verbatim: lemma)
                .font(Typography.display)
                .tracking(-1.2)
                .foregroundStyle(Color.ink)
                .multilineTextAlignment(.center)
                .accessibilityAddTraits(.isHeader)
            HStack(spacing: Spacing.xxs) {
                if let ipa {
                    Text(verbatim: ipa)
                        .font(Typography.secondary)
                        .foregroundStyle(Color.mutedInk)
                        .accessibilityLabel(Text("IPA: \(ipa)"))
                }
                speakButton
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var speakButton: some View {
        Button {
            _ = speech.speak(lemma)
        } label: {
            Image(systemName: speech.isAvailable ? "speaker.wave.2.fill" : "speaker.slash.fill")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(speech.isAvailable ? Color.selectedInk : Color.disabledInk)
                .frame(width: 34, height: 34)
                .background(speech.isAvailable ? Color.selectedSurface : Color.disabledSurface, in: Circle())
                .overlay(Circle().strokeBorder(speech.isSpeaking ? Color.interactive : Color.clear, lineWidth: 1.5))
                .frame(width: Spacing.minTouchTarget, height: Spacing.minTouchTarget)
                .contentShape(Rectangle())
        }
        .buttonStyle(PressScaleButtonStyle())
        .disabled(!speech.isAvailable)
        .accessibilityLabel(Text(speech.isAvailable ? "Play pronunciation" : "Audio unavailable"))
        .accessibilityValue(speech.isSpeaking ? Text("Playing") : Text(verbatim: ""))
    }
}

private struct SenseDetails: View {
    let draft: CustomWordEditDraft
    let tag: LocalizedStringKey?

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                HStack(spacing: Spacing.xs) {
                    Eyebrow(text: "Meaning")
                    Spacer(minLength: 0)
                    if let tag {
                        Chip(text: tag, fill: .selectedSurface, foreground: .selectedInk)
                    }
                }
                Text(verbatim: draft.meaningText)
                    .font(Typography.headerTitle)
                    .foregroundStyle(Color.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }
            section("Definition") {
                Text(verbatim: draft.definitionText)
                    .font(Typography.body)
                    .foregroundStyle(Color.ink)
            }
            ForEach(draft.examples) { example in
                section("Example") {
                    Text(highlightedExample(example.text, at: draft.locator(for: example)))
                        .font(Typography.body)
                        .foregroundStyle(Color.ink)
                }
                section("Translation") {
                    Text(verbatim: example.translation)
                        .font(Typography.body)
                        .foregroundStyle(Color.mutedInk)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func section<Content: View>(_ title: LocalizedStringKey, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Eyebrow(text: title)
            content()
                .fixedSize(horizontal: false, vertical: true)
        }
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

// MARK: - Other steps

private struct EditStage: View {
    let ipa: String?
    let initial: CustomWordEditDraft
    let onBack: () -> Void
    let onSave: (CustomWordEditDraft) -> Void
    @State private var draft: CustomWordEditDraft

    init(
        ipa: String?,
        initial: CustomWordEditDraft,
        onBack: @escaping () -> Void,
        onSave: @escaping (CustomWordEditDraft) -> Void
    ) {
        self.ipa = ipa
        self.initial = initial
        self.onBack = onBack
        self.onSave = onSave
        _draft = State(initialValue: initial)
    }

    var body: some View {
        AddWordScaffold(onBack: onBack) {
            WordHero(lemma: draft.lemma, ipa: ipa)
            CustomWordEditFields(draft: $draft)
        } bar: {
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
    }
}

private struct OtherMeaningStage: View {
    let lemma: String
    let message: String?
    let canRetry: Bool
    let onBack: () -> Void
    @Environment(CustomWordStore.self) private var store
    @State private var context: String

    init(lemma: String, context: String, message: String?, canRetry: Bool, onBack: @escaping () -> Void) {
        self.lemma = lemma
        self.message = message
        self.canRetry = canRetry
        self.onBack = onBack
        _context = State(initialValue: context)
    }

    private var isValid: Bool {
        (1...CustomWordInput.maxContextLength).contains(context.trimmed.utf16.count)
    }

    var body: some View {
        AddWordScaffold(onBack: onBack) {
            WordHero(lemma: lemma, ipa: nil)
            EditorField(
                title: "Meaning to find",
                text: $context,
                maxLength: CustomWordInput.maxContextLength,
                lines: 4...6,
                focusesOnAppear: true
            )
            if let message {
                ErrorText(message: message)
            }
            if canRetry {
                SecondaryButton(title: "Try again", systemImage: "arrow.clockwise") {
                    Task { await store.retryLookup() }
                }
            }
        } bar: {
            PinnedActionBar {
                // The lemma, not the typed form: context only applies to a word the backend already has.
                PrimaryButton(title: "Find meaning", isEnabled: isValid) {
                    Task { await store.lookup(lemma, context: context) }
                }
            }
        }
    }
}

private struct AddedConfirmation: View {
    let lemma: String
    let ipa: String?
    let isNew: Bool
    let onDone: () -> Void

    var body: some View {
        VStack(spacing: Spacing.m) {
            WordHero(lemma: lemma, ipa: ipa)
            Image(systemName: "checkmark")
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(Color.successInk)
                .frame(width: 56, height: 56)
                .background(Color.successSurface, in: Circle())
                .accessibilityHidden(true)
            Text(isNew ? "Word added" : "Already on your path")
                .font(Typography.screenTitle)
                .foregroundStyle(Color.ink)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, Spacing.screenGutter)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .safeAreaInset(edge: .bottom) {
            PinnedActionBar {
                PrimaryButton(title: "Done", action: onDone)
            }
        }
    }
}
