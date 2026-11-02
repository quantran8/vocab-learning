import SwiftUI

/// Sheet adding any word to the learning path: type it, then review what the backend found in a sheet over it.
/// Editing a meaning or looking for another one opens one more sheet on top.
struct AddWordView: View {
    @Environment(CustomWordStore.self) private var store
    @Environment(SpeechPlayer.self) private var speech
    @Environment(\.dismiss) private var dismiss
    @State private var text = ""

    var body: some View {
        // The ZStack ties onDisappear to the sheet, not to each phase's view.
        ZStack { entry }
            .onDisappear {
                store.resetLookup()
                speech.stop()
            }
            .sheet(isPresented: isShowingResult) {
                AddWordResultSheet()
                    .environment(\.closeAddWord, { dismiss() })
            }
            .addWordSheetStyle()
    }

    /// Swiping the result away returns to the word entry, like its back button.
    private var isShowingResult: Binding<Bool> {
        Binding(get: { store.isReviewing }, set: { if !$0 { store.resetLookup() } })
    }

    @ViewBuilder
    private var entry: some View {
        switch store.phase {
        case .loading where !store.isReviewing:
            AddWordScaffold { LookupProgress() }
        case .failed(let message, let canRetry) where !store.isReviewing:
            WordEntry(text: $text, message: message, canRetry: canRetry)
        default:
            WordEntry(text: $text, message: nil, canRetry: false)
        }
    }
}

/// What a lookup found, in its own sheet. Later lookups and the add show here too, until it goes away.
private struct AddWordResultSheet: View {
    @Environment(CustomWordStore.self) private var store
    @Environment(\.closeAddWord) private var closeAddWord

    var body: some View {
        ZStack { content }
            .addWordSheetStyle()
    }

    @ViewBuilder
    private var content: some View {
        switch store.phase {
        case .idle:
            EmptyView()
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
                AddWordScaffold(onBack: store.goBack) {
                    ErrorText(message: message)
                    if canRetry {
                        SecondaryButton(title: "Try again", systemImage: "arrow.clockwise") {
                            Task { await store.retryLookup() }
                        }
                    }
                }
            }
        case .result(let result):
            lookupResult(result)
        case .added(let lemma, let isNew, let ipa):
            AddedConfirmation(lemma: lemma, ipa: ipa, isNew: isNew) { closeAddWord?() }
        }
    }

    @ViewBuilder
    private func lookupResult(_ result: CustomWordLookup) -> some View {
        switch result {
        case .existing(let word):
            let senses = ReviewSense.senses(of: word)
            WordReview(
                lemma: word.lemma,
                senses: senses,
                closed: word.meanings.filter { meaning in !senses.contains { $0.id == meaning.id } },
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

private struct CloseAddWordKey: EnvironmentKey {
    static var defaultValue: (() -> Void)? { nil }
}

private extension EnvironmentValues {
    /// Closes every sheet of the flow. Unset, a sheet's close button closes just that sheet.
    var closeAddWord: (() -> Void)? {
        get { self[CloseAddWordKey.self] }
        set { self[CloseAddWordKey.self] = newValue }
    }
}

private extension View {
    func addWordSheetStyle() -> some View {
        presentationDetents([.large])
            .presentationDragIndicator(.visible)
            .presentationBackground(Color.canvas)
    }
}

/// One step of the sheet: a header, scrolling content, and an action bar pinned to the bottom.
private struct AddWordScaffold<Content: View, Bar: View>: View {
    var onBack: (() -> Void)?
    /// The step's secondary actions, behind a menu button.
    var menu: [HeaderAction] = []
    @ViewBuilder let content: Content
    @ViewBuilder let bar: Bar
    @Environment(\.closeAddWord) private var closeAddWord

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.l) {
                HStack(spacing: Spacing.xs) {
                    if let onBack {
                        SheetBackButton(action: onBack)
                    }
                    if !menu.isEmpty {
                        // Lines the circle up with the content edge, as the back button does.
                        HeaderMenu(actions: menu)
                            .padding(.leading, onBack == nil ? -Spacing.xs : 0)
                    }
                    Spacer()
                    SheetCloseButton(action: closeAddWord)
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
    init(onBack: (() -> Void)? = nil, @ViewBuilder content: () -> Content) {
        self.init(onBack: onBack, content: content, bar: { EmptyView() })
    }
}

private struct HeaderAction: Identifiable {
    let title: LocalizedStringKey
    let systemImage: String
    let action: () -> Void

    var id: String { systemImage }
}

/// Round ⋯ matching the sheet's close button, opening the step's secondary actions.
private struct HeaderMenu: View {
    let actions: [HeaderAction]

    var body: some View {
        Menu {
            ForEach(actions) { item in
                Button(item.title, systemImage: item.systemImage, action: item.action)
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(Color.mutedInk)
                .frame(width: 34, height: 34)
                .background(Color.neutralSurface, in: Circle())
                .frame(width: Spacing.minTouchTarget, height: Spacing.minTouchTarget)
                .contentShape(Rectangle())
        }
        .accessibilityLabel(Text("More actions"))
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
        AddWordScaffold {
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
        // Not while a result sheet covers the entry, or the keyboard would rise over it.
        .onAppear { isFocused = !store.isReviewing }
        .onChange(of: store.isReviewing) { _, isReviewing in
            if !isReviewing { isFocused = true }
        }
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

/// A meaning shown in full, whichever lookup result it came from: one to add, or one the learner already has.
private struct ReviewSense: Identifiable {
    let id: String
    let partOfSpeech: String
    let ipa: String?
    let tag: LocalizedStringKey?
    /// Nil when the meaning is already learned or on the path.
    let addition: CustomWordAddition?
    let standing: ExistingMeaning.Standing?
    let draft: CustomWordEditDraft

    static func senses(of word: ExistingWord) -> [ReviewSense] {
        word.meanings.compactMap { meaning in
            guard meaning.status != .unavailable, meaning.canBeAdded || meaning.standing != nil else { return nil }
            return ReviewSense(
                id: meaning.id,
                partOfSpeech: meaning.partOfSpeech,
                ipa: meaning.ipa,
                tag: meaning.status == .translationDraft ? "AI-translated" : nil,
                addition: meaning.canBeAdded ? meaning.addition : nil,
                standing: meaning.standing,
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
                standing: nil,
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

    /// Opened over the result sheet.
    private enum Sheet: Identifiable {
        case edit, otherMeaning
        var id: Self { self }
    }

    let lemma: String
    let senses: [ReviewSense]
    let closed: [ExistingMeaning]
    let search: Search?
    @Environment(CustomWordStore.self) private var store
    @State private var sheet: Sheet?
    @State private var selectedID: String?
    /// One editable copy per meaning, so switching between them keeps the changes.
    @State private var drafts: [String: CustomWordEditDraft]

    init(lemma: String, senses: [ReviewSense], closed: [ExistingMeaning] = [], search: Search? = nil) {
        self.lemma = lemma
        self.senses = senses
        self.closed = closed
        self.search = search
        // Opens on a meaning that can still be added, when there is one.
        _selectedID = State(initialValue: (senses.first { $0.addition != nil } ?? senses.first)?.id)
        _drafts = State(initialValue: Dictionary(uniqueKeysWithValues: senses.map { ($0.id, $0.draft) }))
    }

    private var selected: ReviewSense? {
        senses.first { $0.id == selectedID }
    }

    var body: some View {
        details
            .sheet(item: $sheet) { item in
                ZStack { sheetContent(item) }
                    .environment(\.closeAddWord, nil)
                    .addWordSheetStyle()
            }
    }

    @ViewBuilder
    private func sheetContent(_ item: Sheet) -> some View {
        switch item {
        case .edit:
            if let selected, let draft = drafts[selected.id] {
                EditStage(ipa: selected.ipa, initial: draft) { edited in
                    drafts[selected.id] = edited
                    sheet = nil
                    add(selected, draft: edited)
                }
            }
        case .otherMeaning:
            OtherMeaningStage(
                lemma: lemma,
                context: search == .searchAgain ? store.lastContext : "",
                message: nil,
                canRetry: false,
                onFind: { sheet = nil }
            )
        }
    }

    /// Swiping the sheet away returns to the word entry, so back is only for an other-meaning result.
    private var back: (() -> Void)? {
        guard store.baseWord != nil else { return nil }
        return { store.goBack() }
    }

    private var details: some View {
        AddWordScaffold(onBack: back, menu: menu) {
            WordHero(lemma: lemma, ipa: selected?.ipa)

            if senses.count > 1 {
                sensePicker
            }
            if let selected, let draft = drafts[selected.id] {
                SenseDetails(draft: draft, tag: selected.tag)
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
                        if let standing = selected?.standing {
                            StandingBadge(standing: standing)
                        } else if let selected {
                            PrimaryButton(title: "Add word", isEnabled: !store.isAdding) {
                                add(selected, draft: drafts[selected.id])
                            }
                        }
                    }
                }
            }
        }
    }

    private var menu: [HeaderAction] {
        var actions: [HeaderAction] = []
        if selected?.addition != nil {
            actions.append(HeaderAction(title: "Edit", systemImage: "pencil") { sheet = .edit })
        }
        switch search {
        case .otherMeaning:
            actions.append(HeaderAction(title: "Other meaning", systemImage: "plus") { sheet = .otherMeaning })
        case .searchAgain:
            actions.append(HeaderAction(title: "Search again", systemImage: "arrow.clockwise") { sheet = .otherMeaning })
        case nil:
            break
        }
        return actions
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
            HStack(spacing: Spacing.xxs) {
                if sense.standing != nil {
                    Image(systemName: "checkmark")
                        .font(Typography.micro.weight(.bold))
                        .foregroundStyle(Color.successInk)
                        .accessibilityHidden(true)
                }
                Text(verbatim: "\(sense.partOfSpeech) · \(drafts[sense.id]?.meaningText ?? "")")
                    .lineLimit(1)
            }
            .font(Typography.secondary.weight(.semibold))
            .foregroundStyle(isSelected ? Color.selectedInk : Color.mutedInk)
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

    private func add(_ sense: ReviewSense, draft: CustomWordEditDraft?) {
        guard var addition = sense.addition else { return }
        addition.edits = draft?.edits
        Task { await store.add(addition, lemma: lemma, ipa: sense.ipa) }
    }
}

/// Takes the add button's place for a meaning the learner already has.
private struct StandingBadge: View {
    let standing: ExistingMeaning.Standing

    var body: some View {
        HStack(spacing: Spacing.xs) {
            Image(systemName: standing == .learned ? "checkmark.seal.fill" : "bookmark.fill")
                .accessibilityHidden(true)
            Text(standing == .learned ? "Already learned" : "On your path")
        }
        .font(Typography.action)
        .foregroundStyle(standing == .learned ? Color.successInk : Color.selectedInk)
        .frame(maxWidth: .infinity, minHeight: Spacing.minTouchTarget)
        .padding(.vertical, Spacing.xxs)
        .background(
            standing == .learned ? Color.successSurface : Color.selectedSurface,
            in: RoundedRectangle(cornerRadius: Radii.primaryAction, style: .continuous)
        )
        .accessibilityElement(children: .combine)
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

/// Its sheet saves the changes and adds the word in one go.
private struct EditStage: View {
    let ipa: String?
    let onSave: (CustomWordEditDraft) -> Void
    @State private var draft: CustomWordEditDraft

    init(ipa: String?, initial: CustomWordEditDraft, onSave: @escaping (CustomWordEditDraft) -> Void) {
        self.ipa = ipa
        self.onSave = onSave
        _draft = State(initialValue: initial)
    }

    var body: some View {
        AddWordScaffold {
            WordHero(lemma: draft.lemma, ipa: ipa)
            CustomWordEditFields(draft: $draft)
        } bar: {
            PinnedActionBar {
                PrimaryButton(
                    title: "Save and add to list",
                    requirement: "Fill in every field",
                    isEnabled: draft.isValid
                ) {
                    onSave(draft)
                }
            }
        }
    }
}

/// In its own sheet it closes as the search starts; shown after a failed search, it has a back button instead.
private struct OtherMeaningStage: View {
    let lemma: String
    let message: String?
    let canRetry: Bool
    let onBack: (() -> Void)?
    let onFind: () -> Void
    @Environment(CustomWordStore.self) private var store
    @State private var context: String

    init(
        lemma: String,
        context: String,
        message: String?,
        canRetry: Bool,
        onBack: (() -> Void)? = nil,
        onFind: @escaping () -> Void = {}
    ) {
        self.lemma = lemma
        self.message = message
        self.canRetry = canRetry
        self.onBack = onBack
        self.onFind = onFind
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
                    let context = context
                    onFind()
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
