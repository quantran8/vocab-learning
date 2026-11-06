import SwiftUI

struct MyWordsView: View {
    @Environment(LearnerStore.self) private var learner
    @Environment(PracticeSessionStore.self) private var practice
    let onOpenRandomPractice: () -> Void
    @State private var query = ""
    @State private var selected: WordProgress?
    @State private var customWordSheet: CustomWordSheet?

    /// Reaching this many rows from the end loads the next page.
    private static let loadMoreDistance = 10

    private var trimmedQuery: String {
        query.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        let words = learner.words
        let stats = learner.wordStats
        let needPractice = stats?.needPracticeWords ?? 0

        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: Spacing.s) {
                    Text("My Words")
                        .font(Typography.display)
                        .tracking(-1.2)
                        .foregroundStyle(Color.ink)
                        .accessibilityAddTraits(.isHeader)
                    Spacer(minLength: 0)
                    addWordButton
                }

                if (stats?.learnedWords ?? words.count) == 0 && learner.wordsQuery.isEmpty {
                    emptyState
                        .padding(.top, Spacing.xl)
                } else {
                    if let stats {
                        LibraryStats(learned: stats.learnedWords, needPractice: needPractice)
                            .padding(.top, Spacing.m)
                    }

                    SectionHeading(text: "Practice")
                        .padding(.top, Spacing.l)

                    HStack(spacing: Spacing.s) {
                        PracticeTile(
                            systemImage: "shuffle",
                            title: "Random Practice",
                            subtitle: "Mixed or by skill",
                            actionTitle: "Start",
                            actionImage: "chevron.right",
                            action: onOpenRandomPractice
                        )
                        PracticeTile(
                            systemImage: "target",
                            title: "Weak Words",
                            subtitle: needPractice > 0 ? "Practice your weak skills" : "Nothing to review yet",
                            actionTitle: needPractice > 0 ? "Start" : "All caught up",
                            actionImage: needPractice > 0 ? "chevron.right" : "checkmark",
                            isEnabled: needPractice > 0,
                            action: { startPractice(.weakWordsPractice) }
                        )
                    }
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, Spacing.s)

                    HStack(alignment: .firstTextBaseline) {
                        SectionHeading(text: "All words")
                        Spacer()
                        manageAddedButton
                    }
                    .padding(.top, Spacing.l)

                    SearchField(placeholder: "Search your words", text: $query)
                        .padding(.top, Spacing.s)

                    wordList(words)
                }
            }
            .padding(.horizontal, Spacing.screenGutter)
            .padding(.top, Spacing.m)
            .padding(.bottom, Spacing.l)
        }
        .scrollDismissesKeyboard(.interactively)
        .refreshable { await learner.refresh() }
        .task(id: trimmedQuery) {
            let search = trimmedQuery
            guard search != learner.wordsQuery else { return }
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            // Detached from this task: leaving the tab must not abandon a query the store already recorded.
            Task { await learner.loadWords(matching: search) }
        }
        .sheet(item: $selected) { word in
            WordDetailSheet(
                wordID: word.wordId,
                lemma: word.lemma,
                ipa: word.ipa,
                playAudio: word.meanings.compactMap(\.meaning.audio).first.map { clip in { practice.playClip(clip) } }
            )
        }
        .sheet(item: $customWordSheet) { sheet in
            switch sheet {
            case .add: AddWordView()
            case .list: CustomWordsView()
            }
        }
    }

    @ViewBuilder
    private func wordList(_ words: [WordProgress]) -> some View {
        if words.isEmpty {
            if learner.isSearchingWords {
                loadingRow
            } else if let error = learner.wordsError {
                retry(error) { await learner.loadWords(matching: trimmedQuery) }
            } else if !learner.wordsQuery.isEmpty {
                Text("No words match “\(learner.wordsQuery)”")
                    .font(Typography.secondary)
                    .foregroundStyle(Color.mutedInk)
                    .padding(.vertical, Spacing.l - 2)
            }
        } else {
            let loadMoreTrigger = words.suffix(Self.loadMoreDistance).first?.id
            LazyVStack(spacing: 0) {
                ForEach(words) { word in
                    row(word, isLast: word.id == words.last?.id)
                        .onAppear {
                            guard word.id == loadMoreTrigger else { return }
                            Task { await learner.loadMoreWords() }
                        }
                }
                if learner.isLoadingMoreWords {
                    loadingRow
                } else if let error = learner.wordsError {
                    retry(error) {
                        if learner.hasMoreWords {
                            await learner.loadMoreWords()
                        } else {
                            await learner.loadWords(matching: trimmedQuery)
                        }
                    }
                }
            }
            .opacity(learner.isSearchingWords ? 0.5 : 1)
            .padding(.top, Spacing.xs)
        }
    }

    private var loadingRow: some View {
        ProgressView()
            .frame(maxWidth: .infinity)
            .padding(.vertical, Spacing.m)
    }

    private func retry(_ message: String, action: @escaping () async -> Void) -> some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            Text(verbatim: message)
                .font(Typography.secondary)
                .foregroundStyle(Color.errorInk)
                .fixedSize(horizontal: false, vertical: true)
            SecondaryButton(title: "Try again", systemImage: "arrow.clockwise") {
                Task { await action() }
            }
        }
        .padding(.vertical, Spacing.m)
    }

    private func startPractice(_ mode: SessionMode) {
        Task { await practice.start(mode) }
    }

    private var addWordButton: some View {
        Button {
            customWordSheet = .add
        } label: {
            let shape = RoundedRectangle(cornerRadius: Radii.primaryAction, style: .continuous)
            Label("Add word", systemImage: "plus")
                .font(Typography.tile)
                .foregroundStyle(Color.ink)
                .padding(.horizontal, Spacing.m)
                .frame(minHeight: Spacing.minTouchTarget + 4)
                .background(Color.surface, in: shape)
                .overlay(shape.strokeBorder(Color.stroke, lineWidth: 1.5))
        }
        .buttonStyle(PressScaleButtonStyle())
    }

    private var manageAddedButton: some View {
        Button {
            customWordSheet = .list
        } label: {
            HStack(spacing: Spacing.xxs) {
                Text("Manage added")
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .accessibilityHidden(true)
            }
            .font(Typography.secondary.weight(.semibold))
            .foregroundStyle(Color.selectedInk)
            .frame(minHeight: Spacing.minTouchTarget)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressScaleButtonStyle())
    }

    private func row(_ word: WordProgress, isLast: Bool) -> some View {
        Button {
            selected = word
        } label: {
            HStack(spacing: Spacing.s) {
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text(verbatim: word.lemma)
                        .font(Typography.tileLarge.weight(.bold))
                        .foregroundStyle(Color.ink)
                    if let ipa = word.ipa {
                        Text(verbatim: ipa)
                            .font(Typography.secondary)
                            .foregroundStyle(Color.mutedInk)
                    }
                    meaningProgress(word)
                        .font(Typography.micro.weight(.semibold))
                        .foregroundStyle(Color.mutedInk)
                        .padding(.top, Spacing.xxs)
                }
                .multilineTextAlignment(.leading)
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Color.mutedInk)
                    .accessibilityHidden(true)
            }
            .padding(.vertical, Spacing.m)
            .overlay(alignment: .bottom) {
                if !isLast {
                    Rectangle().fill(Color.stroke).frame(height: 1)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(PressScaleButtonStyle())
        .accessibilityHint(Text("Shows every meaning of the word"))
    }

    /// The list holds learned meanings only; without the total from the server, it names them instead.
    private func meaningProgress(_ word: WordProgress) -> Text {
        let learned = word.meanings.count
        guard let total = word.meaningCount, total >= learned else {
            return Text(verbatim: word.meaningText)
        }
        return total == 1 ? Text("1 of 1 meaning learned") : Text("\(learned) of \(total) meanings learned")
    }

    private var emptyState: some View {
        VStack(spacing: Spacing.s) {
            RoundedRectangle(cornerRadius: Radii.card, style: .continuous)
                .fill(Color.selectedSurface)
                .frame(width: 72, height: 72)
                .overlay(
                    Image(systemName: "book")
                        .font(.system(size: 30, weight: .semibold))
                        .foregroundStyle(Color.selectedInk)
                )
                .rotationEffect(.degrees(-8))
                .accessibilityHidden(true)
            Text("No words yet")
                .font(Typography.emphasis)
                .foregroundStyle(Color.ink)
                .padding(.top, Spacing.xs)
            Text("Finish today’s flow and your words will collect here.")
                .font(Typography.secondary)
                .foregroundStyle(Color.mutedInk)
                .multilineTextAlignment(.center)
            manageAddedButton
        }
        .frame(maxWidth: .infinity)
    }
}

private enum CustomWordSheet: String, Identifiable {
    case add, list

    var id: String { rawValue }
}

private struct SectionHeading: View {
    let text: LocalizedStringKey

    var body: some View {
        Text(text)
            .font(Typography.screenTitle)
            .tracking(Typography.tightTracking)
            .foregroundStyle(Color.ink)
            .accessibilityAddTraits(.isHeader)
    }
}

/// Two library figures side by side in one strip, split by a hairline.
private struct LibraryStats: View {
    let learned: Int
    let needPractice: Int

    var body: some View {
        HStack(spacing: Spacing.m + Spacing.xxs) {
            figure(learned, caption: "Words learned")
            Rectangle()
                .fill(Color.stroke)
                .frame(width: 1)
                .accessibilityHidden(true)
            figure(needPractice, caption: "Need practice")
        }
        .fixedSize(horizontal: false, vertical: true)
        .padding(Spacing.m + Spacing.xxs)
        .background(Color.neutralSurface, in: RoundedRectangle(cornerRadius: Radii.card, style: .continuous))
    }

    private func figure(_ value: Int, caption: LocalizedStringKey) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(caption)
                .font(Typography.secondary.weight(.semibold))
                .foregroundStyle(Color.mutedInk)
            Text(value, format: .number)
                .font(Typography.display.monospacedDigit())
                .foregroundStyle(Color.ink)
                .contentTransition(.numericText())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

private struct PracticeTile: View {
    let systemImage: String
    let title: LocalizedStringKey
    let subtitle: LocalizedStringKey
    let actionTitle: LocalizedStringKey
    let actionImage: String
    var isEnabled = true
    let action: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            Image(systemName: systemImage)
                .font(.title2.weight(.semibold))
                .foregroundStyle(Color.interactive)
                .padding(.bottom, Spacing.s)
                .accessibilityHidden(true)
            Text(title)
                .font(Typography.tileLarge.weight(.bold))
                .tracking(Typography.tightTracking)
                .foregroundStyle(Color.ink)
            Text(subtitle)
                .font(Typography.secondary)
                .foregroundStyle(Color.mutedInk)
            Spacer(minLength: Spacing.m)
            PrimaryButton(title: actionTitle, systemImage: actionImage, isEnabled: isEnabled, action: action)
        }
        .multilineTextAlignment(.leading)
        .padding(Spacing.m)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .cardSurface()
        .accessibilityElement(children: .combine)
    }
}
