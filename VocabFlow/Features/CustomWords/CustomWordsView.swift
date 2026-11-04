import SwiftUI

/// Sheet listing the words the learner added: tap for details, swipe to edit, restore the original, or remove.
struct CustomWordsView: View {
    @Environment(CustomWordStore.self) private var store
    @State private var selected: CustomWord?
    @State private var editing: CustomWord?
    @State private var removing: CustomWord?

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            HStack {
                ExerciseHeading("Words you added")
                Spacer()
                SheetCloseButton()
            }
            .padding(.horizontal, Spacing.screenGutter)
            content
        }
        .padding(.top, Spacing.l)
        .task { await store.loadWords() }
        .refreshable { await store.loadWords() }
        .onDisappear { store.stopAudio() }
        .sheet(item: $selected) { word in
            WordDetailSheet(
                word: vocabulary(for: word),
                wordID: word.wordId,
                meaningID: word.meaningId,
                playAudio: word.audioUrl == nil ? nil : { store.play(word) }
            )
        }
        .sheet(item: $editing) { word in
            CustomWordEditView(initial: CustomWordEditDraft(word: word)) { edited in
                editing = nil
                guard let edits = edited.edits else { return }
                Task { await store.saveOverride(edits, for: word) }
            }
        }
        .alert(
            "Remove this word?",
            isPresented: Binding(get: { removing != nil }, set: { if !$0 { removing = nil } }),
            presenting: removing
        ) { word in
            Button("Remove", role: .destructive) {
                Task { await store.remove(word) }
            }
            Button("Cancel", role: .cancel) {}
        } message: { _ in
            Text("It won’t be scheduled for review and your edits will be deleted. Your learning history stays.")
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .presentationBackground(Color.canvas)
    }

    @ViewBuilder
    private var content: some View {
        switch store.listPhase {
        case .loading:
            ProgressView()
                .controlSize(.large)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Spacing.xl)
            Spacer(minLength: 0)
        case .failed(let message):
            VStack(alignment: .leading, spacing: Spacing.m) {
                errorText(message)
                SecondaryButton(title: "Try again", systemImage: "arrow.clockwise") {
                    Task { await store.loadWords() }
                }
            }
            .padding(.horizontal, Spacing.screenGutter)
            Spacer(minLength: 0)
        case .ready:
            if let error = store.listError {
                errorText(error)
                    .padding(.horizontal, Spacing.screenGutter)
            }
            if store.words.isEmpty {
                Text("Words you add will collect here.")
                    .font(Typography.secondary)
                    .foregroundStyle(Color.mutedInk)
                    .padding(.horizontal, Spacing.screenGutter)
                Spacer(minLength: 0)
            } else {
                // Swipe actions only exist on List rows.
                List(store.words) { word in
                    row(word)
                        .listRowInsets(EdgeInsets(top: 0, leading: Spacing.screenGutter, bottom: 0, trailing: Spacing.screenGutter))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) { rowActions(word) }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
    }

    private func errorText(_ message: String) -> some View {
        Text(verbatim: message)
            .font(Typography.secondary)
            .foregroundStyle(Color.errorInk)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func row(_ word: CustomWord) -> some View {
        Button {
            if word.isEditable { selected = word }
        } label: {
            HStack(spacing: Spacing.s) {
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text(verbatim: word.lemma)
                        .font(Typography.emphasis)
                        .foregroundStyle(word.recalled ? Color.disabledInk : Color.ink)
                    status(word)
                }
                .multilineTextAlignment(.leading)
                Spacer(minLength: 0)
                if word.isEditable {
                    Image(systemName: "chevron.right")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Color.mutedInk)
                        .accessibilityHidden(true)
                }
            }
            .padding(.vertical, Spacing.m)
            .overlay(alignment: .bottom) {
                Rectangle().fill(Color.neutralSurface).frame(height: 1)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(PressScaleButtonStyle())
        .accessibilityHint(word.isEditable ? Text("Shows the word introduction") : Text(verbatim: ""))
        .opacity(store.busyMeaningIDs.contains(word.meaningId) ? 0.5 : 1)
        .disabled(store.busyMeaningIDs.contains(word.meaningId))
    }

    private func vocabulary(for word: CustomWord) -> VocabularyItem {
        VocabularyItem(
            id: word.meaningId,
            term: word.lemma,
            meaningVi: word.meaningText ?? "",
            example: word.examples?.first?.text ?? "",
            exampleTranslation: word.examples?.first?.translation,
            definitionEN: word.definitionText,
            ipa: word.ipa,
            partsOfSpeech: [word.partOfSpeech]
        )
    }

    @ViewBuilder
    private func status(_ word: CustomWord) -> some View {
        if word.recalled {
            Text("No longer available")
                .font(Typography.micro)
                .foregroundStyle(Color.errorInk)
        } else if word.translationPending {
            Chip(text: "Translating", fill: .neutralSurface, foreground: .mutedInk)
            Text("It joins your sessions once the translation is ready.")
                .font(Typography.micro)
                .foregroundStyle(Color.mutedInk)
                .fixedSize(horizontal: false, vertical: true)
        } else {
            if let meaning = word.meaningText {
                Text(verbatim: meaning)
                    .font(Typography.secondary)
                    .foregroundStyle(Color.mutedInk)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    /// Removal asks first, so it has no destructive role: that role animates the row away before the answer.
    @ViewBuilder
    private func rowActions(_ word: CustomWord) -> some View {
        Button("Remove", systemImage: "trash") { removing = word }
            .tint(Color.errorInk)
        if word.isEditable {
            Button("Edit", systemImage: "pencil") { editing = word }
                .tint(Color.interactive)
            if word.overridden {
                Button("Restore original", systemImage: "arrow.uturn.backward") {
                    Task { await store.restoreOriginal(word) }
                }
                .tint(Color.mutedInk)
            }
        }
    }
}
