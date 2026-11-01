import SwiftUI

struct MyWordsView: View {
    @Environment(LearnerStore.self) private var learner
    @Environment(PracticeSessionStore.self) private var practice
    @State private var today = Date()
    @State private var query = ""
    @State private var selected: WordProgress?

    var body: some View {
        let allWords = learner.words
        let words = allWords.filter { $0.matches(query) }

        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text("My Words")
                    .font(Typography.display)
                    .tracking(-1.2)
                    .foregroundStyle(Color.ink)
                    .accessibilityAddTraits(.isHeader)

                if allWords.isEmpty {
                    emptyState
                        .padding(.top, Spacing.xl)
                } else {
                    LibraryStats(learned: allWords.count, needPractice: allWords.filter(\.needsPractice).count)
                        .padding(.top, Spacing.l - 4)

                    SectionHeading(text: "Practice")
                        .padding(.top, Spacing.l + 4)

                    VStack(spacing: Spacing.s) {
                        PracticeRow(
                            systemImage: "shuffle",
                            tint: .selectedInk,
                            fill: .selectedSurface,
                            title: "Random Practice",
                            subtitle: "Words you haven’t practiced recently",
                            action: { startPractice(.randomPractice) }
                        )
                        PracticeRow(
                            systemImage: "exclamationmark.triangle",
                            tint: .errorInk,
                            fill: .errorSurface,
                            title: "Weak Words Practice",
                            subtitle: "Focus on words you often get wrong",
                            action: { startPractice(.weakWordsPractice) }
                        )
                    }
                    .padding(.top, Spacing.s)

                    HStack(alignment: .firstTextBaseline) {
                        SectionHeading(text: "All words")
                        Spacer()
                        Text("Newest first")
                            .font(Typography.micro)
                            .foregroundStyle(Color.mutedInk)
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
                                row(word, isDue: word.isDue(on: today))
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
    }

    private func startPractice(_ mode: SessionMode) {
        Task { await practice.start(mode) }
    }

    private func row(_ word: WordProgress, isDue: Bool) -> some View {
        Button {
            selected = word
        } label: {
            HStack(spacing: Spacing.s) {
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text(verbatim: word.lemma)
                        .font(Typography.emphasis)
                        .foregroundStyle(Color.ink)
                    Text(verbatim: word.meaningText)
                        .font(Typography.micro)
                        .foregroundStyle(Color.mutedInk)
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 0)
                if isDue {
                    Chip(text: "Review", fill: .selectedSurface, foreground: .selectedInk)
                }
                Image(systemName: "chevron.right")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Color.mutedInk)
                    .accessibilityHidden(true)
            }
            .padding(.vertical, Spacing.m)
            .overlay(alignment: .bottom) {
                Rectangle().fill(Color.neutralSurface).frame(height: 1)
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
        }
        .frame(maxWidth: .infinity)
    }
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

/// Two library figures side by side in one card, split by a hairline.
private struct LibraryStats: View {
    let learned: Int
    let needPractice: Int

    var body: some View {
        HStack(spacing: 0) {
            figure(learned, caption: "Words learned")
            Rectangle()
                .fill(Color.stroke)
                .frame(width: 1)
                .padding(.vertical, Spacing.xxs)
                .accessibilityHidden(true)
            figure(needPractice, caption: "Need practice")
                .padding(.leading, Spacing.m + 2)
        }
        .fixedSize(horizontal: false, vertical: true)
        .padding(Spacing.m + 2)
        .cardSurface(radius: Radii.card - 2)
    }

    private func figure(_ value: Int, caption: LocalizedStringKey) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            Text(value, format: .number)
                .font(Typography.challengeTerm.monospacedDigit())
                .tracking(-1)
                .foregroundStyle(Color.ink)
                .contentTransition(.numericText())
            Text(caption)
                .font(Typography.micro)
                .foregroundStyle(Color.mutedInk)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

private struct PracticeRow: View {
    let systemImage: String
    let tint: Color
    let fill: Color
    let title: LocalizedStringKey
    let subtitle: LocalizedStringKey
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.s + 2) {
                RoundedRectangle(cornerRadius: Radii.chip + 2, style: .continuous)
                    .fill(fill)
                    .frame(width: 42, height: 42)
                    .overlay(
                        Image(systemName: systemImage)
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(tint)
                    )
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text(title)
                        .font(Typography.emphasis)
                        .foregroundStyle(Color.ink)
                    Text(subtitle)
                        .font(Typography.micro)
                        .foregroundStyle(Color.mutedInk)
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Color.mutedInk)
                    .accessibilityHidden(true)
            }
            .padding(Spacing.m)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(ChunkyButtonStyle(kind: .secondary))
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
