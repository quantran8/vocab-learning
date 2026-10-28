import SwiftUI

struct MyWordsView: View {
    @Environment(ProgressStore.self) private var progress
    @Environment(SessionStore.self) private var session
    @Environment(\.motion) private var motion
    @State private var today = Date()
    @State private var query = ""
    @State private var selected: VocabularyItem?

    var body: some View {
        let allWords = progress.progress.learnedWords.sorted { $0.learnedAt > $1.learnedAt }
        let words = allWords.filter { $0.matches(query) }

        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                PunctuatedTitle(text: "My Words")
                Text("Your saved vocabulary")
                    .font(Typography.secondary)
                    .foregroundStyle(Color.mutedInk)
                    .padding(.top, Spacing.xs)

                if allWords.isEmpty {
                    emptyState
                        .padding(.top, Spacing.xl)
                } else {
                    HStack(alignment: .top, spacing: Spacing.s) {
                        StatCard(
                            systemImage: "book",
                            tint: .interactive,
                            title: "Words studied",
                            value: allWords.count,
                            caption: "In your library"
                        )
                        StatCard(
                            systemImage: "arrow.triangle.2.circlepath",
                            tint: .errorInk,
                            title: "Often missed",
                            value: progress.oftenMissedCount(on: today),
                            caption: "Repeated recall misses",
                            footnote: "In the last 30 days"
                        )
                    }
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, Spacing.l)

                    QuickPracticeCard(wordCount: session.totalWords, onStart: startPractice)
                        .padding(.top, Spacing.s)

                    HStack(alignment: .firstTextBaseline) {
                        PlanSectionTitle(text: "All words")
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
                                row(word, isDue: progress.isDue(word, on: today))
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
        .onAppear { today = progress.today }
        .sheet(item: $selected) { word in
            WordDetailSheet(word: word, learnedAt: progress.progress.learnedWords.first { $0.id == word.id }?.learnedAt)
        }
    }

    private func startPractice() {
        progress.beginRun(.review)
        motion.perform(MotionTokens.transition) { session.start() }
    }

    private func row(_ word: LearnedWord, isDue: Bool) -> some View {
        Button {
            selected = vocabulary(for: word)
        } label: {
            HStack(spacing: Spacing.s) {
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text(verbatim: word.term)
                        .font(Typography.emphasis)
                        .foregroundStyle(Color.ink)
                    Text(verbatim: word.meaning)
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

    /// Full content when the word is still in the library; otherwise what was saved when it was learned.
    private func vocabulary(for word: LearnedWord) -> VocabularyItem {
        session.word(id: word.id)
            ?? VocabularyItem(id: word.id, term: word.term, meaningVi: word.meaning, example: "")
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

/// Library figure: icon + eyebrow, a large number, and what it counts. Stretches to its row's height.
private struct StatCard: View {
    let systemImage: String
    let tint: Color
    let title: LocalizedStringKey
    let value: Int
    let caption: LocalizedStringKey
    var footnote: LocalizedStringKey?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: Spacing.xs - 2) {
                Image(systemName: systemImage)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(tint)
                    .accessibilityHidden(true)
                Eyebrow(text: title)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            Text(value, format: .number)
                .font(.system(size: 35, weight: .heavy).monospacedDigit())
                .tracking(-2)
                .foregroundStyle(Color.ink)
                .contentTransition(.numericText())
                .padding(.top, Spacing.s - 2)
            Text(caption)
                .font(Typography.micro.weight(.semibold))
                .foregroundStyle(Color.ink)
                .padding(.top, Spacing.xxs)
            if let footnote {
                Text(footnote)
                    .font(Typography.micro)
                    .foregroundStyle(Color.mutedInk)
                    .padding(.top, 2)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(Spacing.m)
        .cardSurface(radius: Radii.card - 2)
        .accessibilityElement(children: .combine)
    }
}

/// Short review run over the session's words.
private struct QuickPracticeCard: View {
    let wordCount: Int
    let onStart: () -> Void

    /// Roughly 36 seconds per word, rounded up to whole minutes.
    private var minutes: Int { max(1, (wordCount * 3 + 4) / 5) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center) {
                RoundedRectangle(cornerRadius: Radii.chip, style: .continuous)
                    .fill(Color.selectedSurface)
                    .frame(width: 40, height: 40)
                    .overlay(
                        Image(systemName: "sparkle")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(Color.selectedInk)
                    )
                    .accessibilityHidden(true)
                Spacer()
                Label("~\(minutes) min", systemImage: "clock")
                    .font(Typography.micro.weight(.bold))
                    .foregroundStyle(Color.mutedInk)
                    .padding(.horizontal, Spacing.s)
                    .padding(.vertical, Spacing.s - 2)
                    .background(Color.neutralSurface, in: Capsule())
            }

            Text("Quick Practice")
                .font(Typography.headerTitle)
                .tracking(Typography.tightTracking)
                .foregroundStyle(Color.ink)
                .padding(.top, Spacing.m)
            Text("Just \(wordCount) words picked for this round. A little extra practice goes a long way.")
                .font(Typography.secondary)
                .foregroundStyle(Color.mutedInk)
                .padding(.top, Spacing.xxs)

            HStack(spacing: Spacing.xs) {
                Text("\(wordCount) words")
                    .font(Typography.micro.weight(.bold))
                    .foregroundStyle(Color.selectedInk)
                    .padding(.horizontal, Spacing.s)
                    .padding(.vertical, Spacing.s - 2)
                    .background(Color.selectedSurface, in: Capsule())
                Text("No long to-do list")
                    .font(Typography.micro)
                    .foregroundStyle(Color.mutedInk)
            }
            .padding(.top, Spacing.s)

            PrimaryButton(title: "Practice \(wordCount) words", action: onStart)
                .padding(.top, Spacing.m)
        }
        .padding(Spacing.m)
        .cardSurface(radius: Radii.card - 2)
    }
}

/// Bottom sheet with the word's introduction sections; the word itself is shown at rest, without motion.
private struct WordDetailSheet: View {
    let word: VocabularyItem
    let learnedAt: Date?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.l) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: Spacing.xxs) {
                        Eyebrow(text: "Your word", color: .selectedInk)
                        if let learnedAt {
                            Text("Learned \(learnedAt.formatted(date: .abbreviated, time: .omitted))")
                                .font(Typography.micro)
                                .foregroundStyle(Color.mutedInk)
                        }
                    }
                    Spacer()
                    SheetCloseButton()
                        .padding(.top, -Spacing.xs)
                }

                WordIntroContent(word: word)
            }
            .padding(.horizontal, Spacing.screenGutter)
            .padding(.top, Spacing.l)
            .padding(.bottom, Spacing.l)
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .presentationBackground(Color.canvas)
    }
}
