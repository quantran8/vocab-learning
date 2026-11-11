import SwiftUI

/// Home's compact Challenge card. It never suggests the Daily Lesson is blocked, and carries no urgent badge.
struct ChallengeHomeCard: View {
    let onOpenMap: () -> Void
    let onStartDaily: () -> Void
    @Environment(ChallengeMapStore.self) private var store
    @Environment(ChallengeRunStore.self) private var run

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            if let summary = store.summary {
                content(summary)
            } else if let error = store.error {
                Text("Challenge isn’t available right now.")
                    .font(Typography.emphasis)
                    .foregroundStyle(Color.ink)
                Text(verbatim: error)
                    .font(Typography.secondary)
                    .foregroundStyle(Color.mutedInk)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: Spacing.s) {
                    SecondaryButton(title: "Keep Learning", action: onStartDaily)
                    SecondaryButton(title: "Retry") {
                        Task { await store.refresh() }
                    }
                }
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, minHeight: 96)
            }
        }
        .padding(Spacing.m + 2)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardSurface()
    }

    @ViewBuilder
    private func content(_ summary: ChallengeHomeSummary) -> some View {
        switch summary {
        case .notYetEligible(let eligible, let required):
            title("Word Rush")
            Text("Learn words to unlock your first challenge.")
                .font(Typography.secondary)
                .foregroundStyle(Color.mutedInk)
                .fixedSize(horizontal: false, vertical: true)
            wordProgress(eligible: eligible, required: required)
            SecondaryButton(title: "Continue Daily", action: onStartDaily)

        case .chapterReady(let chapterNo):
            HStack(alignment: .center, spacing: Spacing.m) {
                VStack(alignment: .leading, spacing: Spacing.s) {
                    title("Chapter \(chapterNo) unlocked!")
                    HStack(spacing: Spacing.s) {
                        // One empty row per level; the map holds the real count once the chapter exists.
                        ForEach(0..<3, id: \.self) { _ in
                            StarRow(filled: 0, size: 12)
                        }
                    }
                    .accessibilityHidden(true)
                }
                Spacer(minLength: 0)
                // Celebrates once as the card appears, then idles.
                SyllieReactionView(reaction: .happy)
                    .frame(width: 72, height: 72)
                    .accessibilityHidden(true)
            }
            SecondaryButton(title: "Enter Challenge", action: onOpenMap)

        case .inProgress(let chapterNo, let levelNo, let earnedStars, let maxStars):
            HStack(alignment: .firstTextBaseline) {
                title("Chapter \(chapterNo) · Level \(levelNo)")
                Spacer(minLength: Spacing.s)
                starTotal(earnedStars, of: maxStars)
            }
            Text("Match words to their meanings against the clock.")
                .font(Typography.secondary)
                .foregroundStyle(Color.mutedInk)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: Spacing.s) {
                SecondaryButton(title: "Play") {
                    let node = ChallengeNodeRef(chapterNo: chapterNo, levelNo: levelNo)
                    Task { await run.play(node, level: store.level(node)) }
                }
                SecondaryButton(title: "Open Map", action: onOpenMap)
            }

        case .contentUnavailable(let chapterNo, let earnedStars, let maxStars):
            HStack(alignment: .firstTextBaseline) {
                title("Chapter \(chapterNo)")
                Spacer(minLength: Spacing.s)
                starTotal(earnedStars, of: maxStars)
            }
            Text("Some words in this chapter are no longer available. Learn a few more words to keep playing. Your stars are safe.")
                .font(Typography.secondary)
                .foregroundStyle(Color.mutedInk)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: Spacing.s) {
                SecondaryButton(title: "Keep Learning", action: onStartDaily)
                SecondaryButton(title: "Retry") {
                    Task { await store.refresh() }
                }
            }

        case .chapterComplete(let chapterNo, let earnedStars, let maxStars, let nextEligible, let nextRequired):
            HStack(alignment: .firstTextBaseline) {
                title("Chapter \(chapterNo) cleared")
                Spacer(minLength: Spacing.s)
                starTotal(earnedStars, of: maxStars)
            }
            if nextRequired > 0 {
                Text("Next chapter")
                    .font(Typography.secondary)
                    .foregroundStyle(Color.mutedInk)
                wordProgress(eligible: nextEligible, required: nextRequired)
            }
            HStack(spacing: Spacing.s) {
                SecondaryButton(title: "Open Map", action: onOpenMap)
                SecondaryButton(title: "Learn More", action: onStartDaily)
            }
        }
    }

    private func title(_ text: LocalizedStringKey) -> some View {
        Text(text)
            .font(Typography.emphasis)
            .foregroundStyle(Color.ink)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func starTotal(_ earned: Int, of total: Int) -> some View {
        HStack(spacing: Spacing.xxs) {
            Image(systemName: "star.fill")
                .foregroundStyle(Color.reward)
            Text(verbatim: "\(earned) / \(total)")
                .font(Typography.tile.monospacedDigit())
                .foregroundStyle(Color.ink)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("\(earned) of \(total) stars"))
    }

    /// Eligible words as the server counts them: never the My Words total.
    private func wordProgress(eligible: Int, required: Int) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text("\(eligible) / \(required) eligible words")
                .font(Typography.secondary.weight(.bold).monospacedDigit())
                .foregroundStyle(Color.ink)
            ProgressTrack(fraction: required > 0 ? min(CGFloat(eligible) / CGFloat(required), 1) : 0)
                .accessibilityHidden(true)
        }
        .accessibilityElement(children: .combine)
    }
}
