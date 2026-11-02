import SwiftUI

struct MyWordsView: View {
    @Environment(LearnerStore.self) private var learner
    @Environment(PracticeSessionStore.self) private var practice
    @State private var today = Date()
    @State private var query = ""
    @State private var selected: WordProgress?
    @State private var customWordSheet: CustomWordSheet?

    var body: some View {
        let allWords = learner.words
        let words = allWords.filter { $0.matches(query) }

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

                if allWords.isEmpty {
                    emptyState
                        .padding(.top, Spacing.xl)
                } else {
                    let needPractice = allWords.filter(\.needsPractice).count
                    LibraryStats(learned: allWords.count, needPractice: needPractice)
                        .padding(.top, Spacing.m)

                    SectionHeading(text: "Practice")
                        .padding(.top, Spacing.l)

                    HStack(spacing: Spacing.s) {
                        PracticeTile(
                            systemImage: "shuffle",
                            title: "Random Practice",
                            subtitle: "Mixed review",
                            actionTitle: "Start",
                            actionImage: "chevron.right",
                            action: { startPractice(.randomPractice) }
                        )
                        PracticeTile(
                            systemImage: "target",
                            title: "Weak Words",
                            subtitle: needPractice > 0 ? "Focus on mistakes" : "Nothing to review yet",
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

                    if words.isEmpty {
                        Text("No words match “\(query)”")
                            .font(Typography.secondary)
                            .foregroundStyle(Color.mutedInk)
                            .padding(.vertical, Spacing.l - 2)
                    } else {
                        LazyVStack(spacing: 0) {
                            ForEach(words) { word in
                                row(word, isDue: word.isDue(on: today), isLast: word.id == words.last?.id)
                            }
                        }
                        .padding(.top, Spacing.xs)
                    }
                }
            }
            .padding(.horizontal, Spacing.screenGutter)
            .padding(.top, Spacing.m)
            .padding(.bottom, Spacing.l)
        }
        .scrollDismissesKeyboard(.interactively)
        .onAppear { today = .now }
        .refreshable { await learner.refresh() }
        .sheet(item: $selected) { word in
            WordDetailSheet(word: vocabulary(for: word), learnedAt: word.learnedAt, skills: word.meanings.first?.skills)
        }
        .sheet(item: $customWordSheet) { sheet in
            switch sheet {
            case .add: AddWordView()
            case .list: CustomWordsView()
            }
        }
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

    private func row(_ word: WordProgress, isDue: Bool, isLast: Bool) -> some View {
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
                if isDue {
                    Chip(text: "Review", fill: .selectedSurface, foreground: .selectedInk)
                }
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
        VocabularyItem(
            id: word.id,
            term: word.lemma,
            meaningVi: word.meaningText,
            example: "",
            ipa: word.meanings.compactMap(\.meaning.ipa).first
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

/// Bottom sheet with the word's details on one flat page; the word itself is shown at rest, without motion.
private struct WordDetailSheet: View {
    let word: VocabularyItem
    let learnedAt: Date?
    let skills: MeaningSkills?
    @Environment(SpeechPlayer.self) private var speech
    @ScaledMetric(relativeTo: .largeTitle) private var heroFontSize: CGFloat = 48

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Eyebrow(text: "Word detail")
                    Spacer()
                    SheetCloseButton()
                }

                hero
                    .padding(.top, Spacing.l)

                divider

                VStack(alignment: .leading, spacing: Spacing.l) {
                    section("Meaning") {
                        Text(verbatim: word.meaningVi)
                            .font(Typography.headerTitle)
                            .foregroundStyle(Color.ink)
                            .accessibilityLabel(Text("Vietnamese meaning: \(word.meaningVi)"))
                    }
                    if let definition = word.definitionEN {
                        section("Definition") {
                            Text(verbatim: definition)
                                .font(Typography.body)
                                .foregroundStyle(Color.ink)
                        }
                    }
                    if !word.example.isEmpty {
                        section("In context") {
                            Text(LearnView.highlight(word.term, in: word.example))
                                .font(Typography.body)
                                .foregroundStyle(Color.ink)
                        }
                    }
                }

                if let skills {
                    divider
                    section("Skills") {
                        VStack(alignment: .leading, spacing: Spacing.xs) {
                            skillRow("Reading", skills.reading)
                            skillRow("Writing", skills.writing)
                            if let listening = skills.listening {
                                skillRow("Listening", listening)
                            }
                            if let speaking = skills.speaking {
                                skillRow("Speaking", speaking)
                            }
                        }
                    }
                }

                if let learnedAt {
                    divider
                    Text("Learned \(learnedAt.formatted(date: .abbreviated, time: .omitted))")
                        .font(Typography.micro)
                        .foregroundStyle(Color.mutedInk)
                }
            }
            .padding(.horizontal, Spacing.screenGutter)
            .padding(.top, Spacing.m)
            .padding(.bottom, Spacing.l)
        }
        .onDisappear { speech.stop() }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .presentationBackground(Color.canvas)
    }

    private var hero: some View {
        HStack(alignment: .top, spacing: Spacing.s) {
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(verbatim: word.term)
                    .font(.system(size: heroFontSize, weight: .heavy))
                    .tracking(-1.5)
                    .foregroundStyle(Color.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.4)
                    .accessibilityAddTraits(.isHeader)
                if let ipa = word.ipa {
                    Text(verbatim: ipa)
                        .font(Typography.secondary)
                        .foregroundStyle(Color.mutedInk)
                        .accessibilityLabel(Text("IPA: \(ipa)"))
                }
            }
            Spacer(minLength: 0)
            speakButton
                .padding(.top, Spacing.xs)
        }
    }

    private var speakButton: some View {
        Button {
            _ = speech.speak(word.term)
        } label: {
            Image(systemName: speech.isAvailable ? "speaker.wave.2" : "speaker.slash")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(speech.isAvailable ? Color.selectedInk : Color.disabledInk)
                .frame(width: 50, height: 50)
                .background(
                    speech.isAvailable ? Color.selectedSurface : Color.disabledSurface,
                    in: RoundedRectangle(cornerRadius: Radii.tile, style: .continuous)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: Radii.tile, style: .continuous)
                        .strokeBorder(speech.isSpeaking ? Color.interactive : Color.selectedDepth, lineWidth: 1)
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(PressScaleButtonStyle())
        .disabled(!speech.isAvailable)
        .accessibilityLabel(Text(speech.isAvailable ? "Play pronunciation" : "Audio unavailable"))
        .accessibilityValue(speech.isSpeaking ? Text("Playing") : Text(verbatim: ""))
    }

    private func skillRow(_ name: LocalizedStringKey, _ skill: SkillState) -> some View {
        HStack {
            Text(name)
                .font(Typography.body)
                .foregroundStyle(Color.ink)
            Spacer()
            Text(skillStatus(skill.status))
                .font(Typography.micro.weight(.semibold))
                .foregroundStyle(skill.needsPractice ? Color.errorInk : Color.mutedInk)
        }
        .accessibilityElement(children: .combine)
    }

    private func skillStatus(_ status: SkillStatus) -> LocalizedStringKey {
        switch status {
        case .notVerified: "Not verified"
        case .demonstrated: "Demonstrated"
        case .verified: "Verified"
        }
    }

    private var divider: some View {
        Rectangle()
            .fill(Color.stroke)
            .frame(height: 1)
            .padding(.vertical, Spacing.l)
    }

    private func section<Content: View>(_ title: LocalizedStringKey, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Eyebrow(text: title)
                .accessibilityAddTraits(.isHeader)
            content()
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
