import SwiftUI

struct PartOfSpeechGroup<Item>: Identifiable {
    let partOfSpeech: String
    let items: [Item]

    var id: String { partOfSpeech }

    /// Groups keep the order in which their part of speech first appears.
    static func grouping(_ items: [Item], by partOfSpeech: (Item) -> String) -> [PartOfSpeechGroup<Item>] {
        var order: [String] = []
        var buckets: [String: [Item]] = [:]
        for item in items {
            let key = partOfSpeech(item)
            if buckets[key] == nil { order.append(key) }
            buckets[key, default: []].append(item)
        }
        return order.map { PartOfSpeechGroup(partOfSpeech: $0, items: buckets[$0] ?? []) }
    }
}

/// Definition and first example of one meaning.
struct MeaningFields: View {
    enum Style { case divided, quiet }

    let lemma: String
    let sense: WordMeaning.Sense
    var style = Style.divided

    var body: some View {
        let definition = sense.definition.flatMap { $0.isEmpty ? nil : $0 }
        VStack(alignment: .leading, spacing: 0) {
            if let definition {
                field("Definition") {
                    Text(verbatim: definition)
                }
            }
            if let example = sense.examples?.first {
                if style == .divided && definition != nil {
                    Rectangle().fill(Color.stroke).frame(height: 1)
                }
                field("In context") {
                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        Text(LearnView.highlight(lemma, in: example.text))
                        if let translation = example.translation, !translation.isEmpty {
                            ExampleTranslation(text: translation, showsIcon: style == .divided)
                        }
                    }
                }
            }
        }
    }

    private func field<Content: View>(_ title: LocalizedStringKey, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Eyebrow(text: title)
                .accessibilityAddTraits(.isHeader)
            content()
                .font(Typography.body)
                .foregroundStyle(Color.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, style == .divided ? Spacing.s : Spacing.xs)
    }
}

/// A backend part of speech styled as an eyebrow; it is data, so it can't go through `Eyebrow`.
private struct PartOfSpeechEyebrow: View {
    let value: String

    var body: some View {
        Text(verbatim: VocabularyItem.localizedPartOfSpeech(value))
            .font(Typography.eyebrow)
            .tracking(Typography.eyebrowTracking)
            .textCase(.uppercase)
            .foregroundStyle(Color.mutedInk)
            .accessibilityAddTraits(.isHeader)
    }
}

private struct ExpandChevron: View {
    let isExpanded: Bool

    var body: some View {
        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
            .font(.subheadline.weight(.medium))
            .foregroundStyle(Color.mutedInk)
            .accessibilityHidden(true)
    }
}

// MARK: - Other meanings (word introduction)

/// Reference sheet from a learn step: the word's other meanings, outside the lesson.
struct OtherMeaningsSheet: View {
    let lemma: String
    let meanings: [WordDetail.Meaning]
    @Environment(\.motion) private var motion
    @State private var expandedID: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top, spacing: Spacing.s) {
                    VStack(alignment: .leading, spacing: Spacing.xxs) {
                        Text("Other meanings of “\(lemma)”")
                            .font(Typography.screenTitle)
                            .tracking(Typography.tightTracking)
                            .foregroundStyle(Color.ink)
                            .accessibilityAddTraits(.isHeader)
                        Text("For reference only · Not part of this lesson")
                            .font(Typography.secondary)
                            .foregroundStyle(Color.mutedInk)
                    }
                    .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                    SheetCloseButton()
                }
                .padding(.bottom, Spacing.m)

                ForEach(PartOfSpeechGroup.grouping(meanings) { $0.meaning.partOfSpeech }) { group in
                    VStack(alignment: .leading, spacing: 0) {
                        Rectangle().fill(Color.stroke).frame(height: 1)
                        PartOfSpeechEyebrow(value: group.partOfSpeech)
                            .padding(.top, Spacing.m)
                            .padding(.bottom, Spacing.xxs)
                        ForEach(group.items, id: \.meaningId) { item in
                            row(item, isLast: item.meaningId == group.items.last?.meaningId)
                        }
                    }
                    .padding(.bottom, Spacing.xs)
                }
            }
            .padding(.horizontal, Spacing.screenGutter)
            .padding(.top, Spacing.l)
            .padding(.bottom, Spacing.l)
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .presentationBackground(Color.canvas)
    }

    private func row(_ item: WordDetail.Meaning, isLast: Bool) -> some View {
        let isExpanded = expandedID == item.meaningId
        return VStack(alignment: .leading, spacing: 0) {
            Button {
                motion.perform(MotionTokens.snap) { expandedID = isExpanded ? nil : item.meaningId }
            } label: {
                HStack(spacing: Spacing.s) {
                    Text(verbatim: item.meaning.text)
                        .font(Typography.tile)
                        .foregroundStyle(Color.ink)
                        .multilineTextAlignment(.leading)
                    Spacer(minLength: 0)
                    ExpandChevron(isExpanded: isExpanded)
                }
                .frame(minHeight: Spacing.minTouchTarget + Spacing.xs)
                .contentShape(Rectangle())
            }
            .buttonStyle(PressScaleButtonStyle())
            .accessibilityValue(Text(isExpanded ? "Expanded" : "Collapsed"))

            if isExpanded {
                MeaningFields(lemma: lemma, sense: item.meaning, style: .quiet)
                    .padding(Spacing.s)
                    .background(Color.quietSurface, in: RoundedRectangle(cornerRadius: Radii.tile, style: .continuous))
                    .padding(.bottom, Spacing.s)
                    .transition(.opacity)
            }
        }
        .overlay(alignment: .bottom) {
            if !isLast {
                Rectangle().fill(Color.stroke).frame(height: 1)
            }
        }
    }
}

// MARK: - Word detail (My Words)

/// Every meaning of a word grouped by part of speech; progress belongs to each meaning, not the word.
struct WordDetailSheet: View {
    private enum Load: Equatable {
        case loading, failed
        case loaded(WordDetail)
    }

    let wordID: String
    let lemma: String
    let ipa: String?
    /// Opens expanded; otherwise the first learned meaning does.
    var focusMeaningID: String?
    /// Plays recorded audio when there is some; otherwise the word is spoken by the device.
    let playAudio: (() -> Void)?
    /// Whether `playAudio`'s clip is playing right now, for the speaker waves.
    var isPlayingAudio = false
    @Environment(LearnerStore.self) private var learner
    @Environment(SpeechPlayer.self) private var speech
    @Environment(\.motion) private var motion
    @State private var load = Load.loading
    @State private var expandedID: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Spacer()
                    SheetCloseButton()
                }

                VStack(spacing: Spacing.xs) {
                    IntroMotionHost(
                        word: lemma,
                        presentation: VocabularyItem(id: wordID, term: lemma, meaningVi: "", example: "").introPresentation,
                        animates: false
                    )
                    WordPronunciation(term: lemma, ipa: ipa, playAudio: playAudio, isPlayingAudio: isPlayingAudio)
                }
                .frame(maxWidth: .infinity)
                .padding(.bottom, Spacing.l)

                meanings
            }
            .padding(.horizontal, Spacing.screenGutter)
            .padding(.top, Spacing.m)
            .padding(.bottom, Spacing.l)
        }
        .task { await loadDetail() }
        .onDisappear { speech.stop() }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .presentationBackground(Color.canvas)
    }

    @ViewBuilder
    private var meanings: some View {
        HStack(alignment: .firstTextBaseline) {
            Eyebrow(text: "Meanings")
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: Spacing.s)
            if case .loaded(let detail) = load {
                let learned = detail.meanings.filter { $0.learnedAt != nil }.count
                Text("\(learned) / \(detail.meanings.count) learned")
                    .font(Typography.micro)
                    .foregroundStyle(Color.mutedInk)
            }
        }
        .padding(.bottom, Spacing.xs)

        switch load {
        case .loading:
            ProgressView()
                .frame(maxWidth: .infinity)
                .padding(.vertical, Spacing.l)
        case .failed:
            VStack(alignment: .leading, spacing: Spacing.s) {
                Text("Couldn’t load this word")
                    .font(Typography.secondary)
                    .foregroundStyle(Color.errorInk)
                SecondaryButton(title: "Try again", systemImage: "arrow.clockwise") {
                    Task { await loadDetail() }
                }
            }
            .padding(.vertical, Spacing.m)
        case .loaded(let detail):
            ForEach(PartOfSpeechGroup.grouping(detail.meanings) { $0.meaning.partOfSpeech }) { group in
                VStack(alignment: .leading, spacing: 0) {
                    Text(verbatim: VocabularyItem.localizedPartOfSpeech(group.partOfSpeech))
                        .font(Typography.emphasis)
                        .foregroundStyle(Color.ink)
                        .accessibilityAddTraits(.isHeader)
                        .padding(.top, Spacing.s)
                    ForEach(Array(group.items.enumerated()), id: \.element.meaningId) { index, item in
                        row(item, number: index + 1, isLast: index == group.items.count - 1)
                    }
                }
                .padding(.bottom, Spacing.s)
            }
        }
    }

    private func row(_ item: WordDetail.Meaning, number: Int, isLast: Bool) -> some View {
        let isExpanded = expandedID == item.meaningId
        return VStack(alignment: .leading, spacing: 0) {
            Button {
                motion.perform(MotionTokens.snap) { expandedID = isExpanded ? nil : item.meaningId }
            } label: {
                HStack(spacing: Spacing.xs) {
                    Text(verbatim: "\(number).")
                        .font(Typography.secondary.monospacedDigit())
                        .foregroundStyle(Color.mutedInk)
                        .frame(width: Spacing.m, alignment: .leading)
                    Text(verbatim: item.meaning.text)
                        .font(Typography.tile)
                        .foregroundStyle(Color.ink)
                        .multilineTextAlignment(.leading)
                    Spacer(minLength: Spacing.xs)
                    learnedLabel(item.learnedAt != nil)
                    ExpandChevron(isExpanded: isExpanded)
                }
                .frame(minHeight: Spacing.tileMinHeight)
                .contentShape(Rectangle())
            }
            .buttonStyle(PressScaleButtonStyle())
            .accessibilityValue(Text(isExpanded ? "Expanded" : "Collapsed"))

            if isExpanded {
                expandedContent(item)
                    .padding(.leading, Spacing.m + Spacing.xs)
                    .padding(.bottom, Spacing.s)
                    .transition(.opacity)
            }
        }
        .overlay(alignment: .bottom) {
            if !isLast {
                Rectangle().fill(Color.stroke).frame(height: 1)
            }
        }
    }

    private func learnedLabel(_ isLearned: Bool) -> some View {
        HStack(spacing: Spacing.xxs) {
            if isLearned {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(Color.success)
                    .accessibilityHidden(true)
            }
            Text(isLearned ? "Learned" : "Not learned")
        }
        .font(Typography.micro.weight(isLearned ? .semibold : .regular))
        .foregroundStyle(isLearned ? Color.ink : Color.mutedInk)
        .fixedSize()
    }

    @ViewBuilder
    private func expandedContent(_ item: WordDetail.Meaning) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            MeaningFields(lemma: lemma, sense: item.meaning)
            if let learnedAt = item.learnedAt {
                Eyebrow(text: "Skills")
                    .accessibilityAddTraits(.isHeader)
                    .padding(.top, Spacing.s)
                    .padding(.bottom, Spacing.xs)
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    skillRow("Reading", item.skills.reading)
                    skillRow("Writing", item.skills.writing)
                    if let listening = item.skills.listening {
                        skillRow("Listening", listening)
                    }
                    if let speaking = item.skills.speaking {
                        skillRow("Speaking", speaking)
                    }
                }
                Text("Learned \(learnedAt.formatted(Date.FormatStyle(date: .abbreviated, time: .omitted, locale: AppLanguage.active.locale)))")
                    .font(Typography.micro)
                    .foregroundStyle(Color.mutedInk)
                    .padding(.top, Spacing.s)
            } else {
                Text("This meaning hasn’t been learned yet. No skill progress is available.")
                    .font(Typography.secondary)
                    .foregroundStyle(Color.mutedInk)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, Spacing.s)
            }
        }
    }

    private func loadDetail() async {
        load = .loading
        do {
            let detail = try await learner.wordDetail(id: wordID)
            if expandedID == nil {
                let ids = detail.meanings.map(\.meaningId)
                expandedID = focusMeaningID.flatMap { ids.contains($0) ? $0 : nil }
                    ?? detail.meanings.first { $0.learnedAt != nil }?.meaningId
                    ?? ids.first
            }
            load = .loaded(detail)
        } catch {
            guard !Task.isCancelled else { return }
            load = .failed
        }
    }

    private func skillRow(_ name: LocalizedStringKey, _ skill: SkillState) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: Spacing.m) {
            Text(name)
                .font(Typography.body)
                .foregroundStyle(Color.ink)
            Spacer(minLength: 0)
            HStack(spacing: Spacing.xxs) {
                if skill.issue == nil && skill.status == .verified {
                    Image(systemName: "checkmark")
                        .accessibilityHidden(true)
                }
                Text(skillLabel(skill))
                    .multilineTextAlignment(.trailing)
            }
            .font(Typography.micro.weight(.semibold))
            .foregroundStyle(skillColor(skill))
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
        switch (skill.issue, skill.status) {
        case (.failed, _): .errorInk
        case (.assisted, _): .selectedInk
        case (nil, .verified): .ink
        case (nil, _): .mutedInk
        }
    }
}
