import SwiftUI

/// A level's goal and star rules (from the map; the run plan has the final say), personal best, and Play. Locked levels explain how to open them.
struct ChallengeLevelSheet: View {
    let node: ChallengeNodeRef
    let chapter: ChallengeChapter?
    let level: ChallengeLevel?
    let onPlay: () -> Void
    /// The untimed familiarization round (no stars, no unlocks), offered to VoiceOver and Switch Control users.
    let onPracticeUntimed: () -> Void
    @Environment(LearnerStore.self) private var learner
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOver
    @Environment(\.accessibilitySwitchControlEnabled) private var switchControl

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.l) {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text("Chapter \(node.chapterNo) · Level \(node.levelNo)")
                        .font(Typography.eyebrow)
                        .tracking(Typography.eyebrowTracking)
                        .textCase(.uppercase)
                        .foregroundStyle(Color.mutedInk)
                    Text("Match Madness")
                        .font(Typography.display)
                        .tracking(-1.2)
                        .foregroundStyle(Color.ink)
                        .accessibilityAddTraits(.isHeader)
                }

                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text("Match each word to its meaning before time runs out.")
                        .font(Typography.body)
                        .foregroundStyle(Color.ink)
                    if let level, let goal = level.goalMatches, let timeLimitMs = level.timeLimitMs {
                        Text("Match \(goal) pairs in \(timeLimitMs / 1000) seconds")
                            .font(Typography.secondary)
                            .foregroundStyle(Color.mutedInk)
                    }
                }
                .fixedSize(horizontal: false, vertical: true)

                if let criteria = level?.starCriteria, let timeLimitMs = level?.timeLimitMs {
                    StarRules(criteria: criteria, timeLimitMs: timeLimitMs)
                }

                if let level, level.state == .cleared {
                    best(level)
                }

                if let note = localeNote {
                    Text(note)
                        .font(Typography.micro)
                        .foregroundStyle(Color.mutedInk)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if level?.isPlayable == true {
                    VStack(spacing: Spacing.s) {
                        PrimaryButton(title: "Play", shimmers: true, action: onPlay)
                        if voiceOver || switchControl {
                            SecondaryButton(title: "Practise untimed", action: onPracticeUntimed)
                            Text("An untimed practice round with example words. It earns no stars.")
                                .font(Typography.micro)
                                .foregroundStyle(Color.mutedInk)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                } else {
                    Label {
                        Text("Clear the previous level to unlock.")
                    } icon: {
                        Image(systemName: "lock.fill")
                    }
                    .font(Typography.secondary.weight(.semibold))
                    .foregroundStyle(Color.mutedInk)
                }
            }
            .padding(.horizontal, Spacing.screenGutter)
            .padding(.top, Spacing.l)
            .padding(.bottom, Spacing.m)
        }
    }

    private func best(_ level: ChallengeLevel) -> some View {
        HStack(spacing: Spacing.s) {
            Text("Best")
                .font(Typography.secondary.weight(.bold))
                .foregroundStyle(Color.mutedInk)
            StarRow(filled: level.bestStars, size: 18)
            if level.bestScore > 0 {
                Text("\(level.bestScore) points")
                    .font(Typography.secondary.monospacedDigit())
                    .foregroundStyle(Color.ink)
            }
        }
        .accessibilityElement(children: .combine)
    }

    /// "vi-VN" and "vi" are the same meaning language.
    private static func languageCode(_ identifier: String) -> String {
        String(identifier.lowercased().split(whereSeparator: { $0 == "-" || $0 == "_" }).first ?? "")
    }

    /// A chapter keeps the meaning language it was frozen in, even after the setting changed.
    private var localeNote: LocalizedStringKey? {
        guard let frozenLocale = chapter?.explanationLocale,
              let currentLocale = learner.profile?.settings.explanationLocale,
              case let frozen = Self.languageCode(frozenLocale),
              case let current = Self.languageCode(currentLocale),
              frozen != current else { return nil }
        let name = AppLanguage.active.locale.localizedString(forLanguageCode: frozen) ?? frozen
        return "This chapter uses \(name) meanings."
    }
}
