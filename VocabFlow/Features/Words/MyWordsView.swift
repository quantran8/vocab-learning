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
                word: vocabulary(for: word),
                wordID: word.wordId,
                meaningID: word.meanings.first?.meaningId,
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
                        .font(Typography.emphasis)
                        .foregroundStyle(Color.ink)
                    Text(verbatim: word.meaningText)
                        .font(Typography.secondary)
                        .foregroundStyle(Color.mutedInk)
                        .multilineTextAlignment(.leading)
                }
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
        .accessibilityHint(Text("Shows the word introduction"))
    }

    private func vocabulary(for word: WordProgress) -> VocabularyItem {
        let example = word.meanings.compactMap { $0.meaning.examples?.first }.first
        var partsOfSpeech: [String] = []
        for meaning in word.meanings where !partsOfSpeech.contains(meaning.meaning.partOfSpeech) {
            partsOfSpeech.append(meaning.meaning.partOfSpeech)
        }
        return VocabularyItem(
            id: word.id,
            term: word.lemma,
            meaningVi: word.meaningText,
            example: example?.text ?? "",
            exampleTranslation: example?.translation,
            definitionEN: word.meanings.compactMap(\.meaning.definition).first,
            ipa: word.meanings.compactMap(\.meaning.ipa).first,
            partsOfSpeech: partsOfSpeech
        )
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

/// Bottom sheet that opens with the same introduction the word got in its learn step, with the word
/// at rest instead of animated, followed by the learner's skill progress.
struct WordDetailSheet: View {
    private enum Progress: Equatable {
        case loading, failed
        case loaded(WordDetail.Meaning?)
    }

    let word: VocabularyItem
    let wordID: String
    let meaningID: String?
    /// Plays recorded audio when there is some; otherwise the word is spoken by the device.
    let playAudio: (() -> Void)?
    @Environment(LearnerStore.self) private var learner
    @State private var progress = Progress.loading

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Spacer()
                    SheetCloseButton()
                }

                WordIntroContent(
                    word: word,
                    presentation: word.introPresentation,
                    playAudio: playAudio,
                    animatesWord: false
                )
                .padding(.top, Spacing.s)
                .padding(.bottom, Spacing.m)

                progressContent
            }
            .padding(.horizontal, Spacing.screenGutter)
            .padding(.top, Spacing.m)
            .padding(.bottom, Spacing.l)
        }
        .task { await loadProgress() }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .presentationBackground(Color.canvas)
    }

    /// A meaning that isn't learned yet has no progress to show.
    @ViewBuilder
    private var progressContent: some View {
        switch progress {
        case .loading:
            section("Skills") {
                ProgressView()
            }
        case .failed:
            section("Skills") {
                VStack(alignment: .leading, spacing: Spacing.s) {
                    Text("Couldn’t load your skills")
                        .font(Typography.secondary)
                        .foregroundStyle(Color.errorInk)
                    SecondaryButton(title: "Try again", systemImage: "arrow.clockwise") {
                        Task { await loadProgress() }
                    }
                }
            }
        case .loaded(let meaning):
            if let meaning, let learnedAt = meaning.learnedAt {
                section("Skills") {
                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        skillRow("Reading", meaning.skills.reading)
                        skillRow("Writing", meaning.skills.writing)
                        if let listening = meaning.skills.listening {
                            skillRow("Listening", listening)
                        }
                        if let speaking = meaning.skills.speaking {
                            skillRow("Speaking", speaking)
                        }
                    }
                }
                Text("Learned \(learnedAt.formatted(Date.FormatStyle(date: .abbreviated, time: .omitted, locale: AppLanguage.active.locale)))")
                    .font(Typography.micro)
                    .foregroundStyle(Color.mutedInk)
            }
        }
    }

    private func loadProgress() async {
        progress = .loading
        do {
            let detail = try await learner.wordDetail(id: wordID)
            progress = .loaded(detail.meanings.first { $0.meaningId == meaningID })
        } catch {
            guard !Task.isCancelled else { return }
            progress = .failed
        }
    }

    private func skillRow(_ name: LocalizedStringKey, _ skill: SkillState) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: Spacing.m) {
            Text(name)
                .font(Typography.body)
                .foregroundStyle(Color.ink)
            Spacer(minLength: 0)
            Text(skillLabel(skill))
                .font(Typography.micro.weight(.semibold))
                .foregroundStyle(skillColor(skill))
                .multilineTextAlignment(.trailing)
        }
        .accessibilityElement(children: .combine)
    }

    // Copy rules: memory skill-issue-display
    private func skillLabel(_ skill: SkillState) -> LocalizedStringKey {
        switch (skill.issue, skill.status) {
        case (.failed, _): "Needs practice again"
        case (.assisted, .verified): "Verified, but recently needed help"
        case (.assisted, _): "Recently needed help"
        case (nil, .verified): "Verified"
        case (nil, .demonstrated): "Demonstrated"
        case (nil, .notVerified): "Not verified"
        }
    }

    private func skillColor(_ skill: SkillState) -> Color {
        switch skill.issue {
        case .failed: .errorInk
        case .assisted: .selectedInk
        case nil: .mutedInk
        }
    }

    private func section<Content: View>(_ title: LocalizedStringKey, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Eyebrow(text: title)
                .accessibilityAddTraits(.isHeader)
            content()
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.bottom, Spacing.xl)
    }
}
