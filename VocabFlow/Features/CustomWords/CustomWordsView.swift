import SwiftUI

/// Sheet listing the words the learner added: edit, restore the original, or remove.
struct CustomWordsView: View {
    @Environment(CustomWordStore.self) private var store
    @State private var editing: CustomWord?
    @State private var removing: CustomWord?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.m) {
                HStack {
                    Eyebrow(text: "My Words")
                    Spacer()
                    SheetCloseButton()
                }
                ExerciseHeading("Words you added")
                content
            }
            .padding(.horizontal, Spacing.screenGutter)
            .padding(.top, Spacing.l)
            .padding(.bottom, Spacing.l)
        }
        .task { await store.loadWords() }
        .refreshable { await store.loadWords() }
        .onDisappear { store.stopAudio() }
        .sheet(item: $editing) { word in
            CustomWordEditView(initial: CustomWordEditDraft(word: word)) { edited in
                editing = nil
                guard let edits = edited.edits else { return }
                Task { await store.saveOverride(edits, for: word) }
            }
        }
        .confirmationDialog(
            "Remove this word?",
            isPresented: Binding(get: { removing != nil }, set: { if !$0 { removing = nil } }),
            titleVisibility: .visible,
            presenting: removing
        ) { word in
            Button("Remove", role: .destructive) {
                Task { await store.remove(word) }
            }
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
        case .failed(let message):
            Text(verbatim: message)
                .font(Typography.secondary)
                .foregroundStyle(Color.errorInk)
                .fixedSize(horizontal: false, vertical: true)
            SecondaryButton(title: "Try again", systemImage: "arrow.clockwise") {
                Task { await store.loadWords() }
            }
        case .ready:
            if let error = store.listError {
                Text(verbatim: error)
                    .font(Typography.secondary)
                    .foregroundStyle(Color.errorInk)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if store.words.isEmpty {
                Text("Words you add will collect here.")
                    .font(Typography.secondary)
                    .foregroundStyle(Color.mutedInk)
            } else {
                LazyVStack(spacing: 0) {
                    ForEach(store.words) { word in
                        row(word)
                    }
                }
            }
        }
    }

    private func row(_ word: CustomWord) -> some View {
        HStack(alignment: .top, spacing: Spacing.s) {
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                HStack(spacing: Spacing.xs) {
                    Text(verbatim: word.lemma)
                        .font(Typography.emphasis)
                        .foregroundStyle(word.recalled ? Color.disabledInk : Color.ink)
                    Text(verbatim: word.partOfSpeech)
                        .font(Typography.micro)
                        .foregroundStyle(Color.mutedInk)
                    if word.overridden && word.isEditable {
                        Chip(text: "Edited", fill: .selectedSurface, foreground: .selectedInk)
                    }
                }
                status(word)
            }
            Spacer(minLength: 0)
            if word.audioUrl != nil && !word.recalled {
                Button {
                    store.play(word)
                } label: {
                    Image(systemName: "speaker.wave.2")
                        .foregroundStyle(Color.selectedInk)
                        .frame(width: Spacing.minTouchTarget, height: Spacing.minTouchTarget)
                        .contentShape(Rectangle())
                }
                .buttonStyle(PressScaleButtonStyle())
                .accessibilityLabel(Text("Play pronunciation"))
            }
            actions(word)
        }
        .padding(.vertical, Spacing.s)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Color.neutralSurface).frame(height: 1)
        }
        .opacity(store.busyMeaningIDs.contains(word.meaningId) ? 0.5 : 1)
        .disabled(store.busyMeaningIDs.contains(word.meaningId))
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
                    .foregroundStyle(Color.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let definition = word.definitionText {
                Text(verbatim: definition)
                    .font(Typography.micro)
                    .foregroundStyle(Color.mutedInk)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func actions(_ word: CustomWord) -> some View {
        Menu {
            if word.isEditable {
                Button("Edit", systemImage: "pencil") { editing = word }
                if word.overridden {
                    Button("Restore original", systemImage: "arrow.uturn.backward") {
                        Task { await store.restoreOriginal(word) }
                    }
                }
            }
            Button("Remove", systemImage: "trash", role: .destructive) { removing = word }
        } label: {
            Image(systemName: "ellipsis")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(Color.mutedInk)
                .frame(width: Spacing.minTouchTarget, height: Spacing.minTouchTarget)
                .contentShape(Rectangle())
        }
        .accessibilityLabel(Text("Actions for \(word.lemma)"))
    }
}
