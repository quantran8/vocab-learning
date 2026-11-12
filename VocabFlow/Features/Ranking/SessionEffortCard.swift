import SwiftUI

/// "+N LP" under the session results, and the Tier this session unlocked. Never a rank change (spec §3.5, §10).
struct SessionEffortCard: View {
    let effort: SessionEffort
    @Environment(\.motion) private var motion

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            lpSummary
            if let tierUp = effort.celebratedTierUp, let key = tierUp.key {
                Divider().overlay(Color.neutralSurface)
                tierUnlocked(key)
            }
        }
        .padding(Spacing.m)
        .cardSurface(radius: Radii.card - 2)
        .accessibilityElement(children: .combine)
    }

    private var lpSummary: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack(alignment: .firstTextBaseline) {
                Text("+\(effort.earned) LP")
                    .font(Typography.screenTitle.monospacedDigit())
                    .foregroundStyle(Color.ink)
                Spacer(minLength: Spacing.s)
                Text("\(effort.lifetimeLP) LP in total")
                    .font(Typography.micro)
                    .foregroundStyle(Color.mutedInk)
            }
            if effort.earned == 0 {
                Text("Each word earns LP a limited number of times a day, so this session added none.")
                    .font(Typography.micro)
                    .foregroundStyle(Color.mutedInk)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                FlowLayout(spacing: Spacing.xs, lineSpacing: Spacing.xs, alignment: .leading) {
                    if effort.breakdown.newMeaningLP > 0 { part("New words +\(effort.breakdown.newMeaningLP)") }
                    if effort.breakdown.dueReviewLP > 0 { part("Reviews +\(effort.breakdown.dueReviewLP)") }
                    if effort.breakdown.extraPracticeLP > 0 { part("Extra practice +\(effort.breakdown.extraPracticeLP)") }
                }
            }
        }
    }

    private func part(_ text: LocalizedStringKey) -> some View {
        Text(text)
            .font(Typography.micro.weight(.semibold))
            .foregroundStyle(Color.selectedInk)
            .padding(.horizontal, Spacing.s - 2)
            .padding(.vertical, Spacing.xxs + 1)
            .background(Color.selectedSurface, in: Capsule())
    }

    private func tierUnlocked(_ key: TierKey) -> some View {
        HStack(alignment: .top, spacing: Spacing.s) {
            SyllieReactionView(reaction: motion.reduceMotion ? .idle : key.mood)
                .frame(width: 64, height: 56)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text("You unlocked \(key.localizedName)")
                    .font(Typography.emphasis)
                    .foregroundStyle(Color.ink)
                    .fixedSize(horizontal: false, vertical: true)
                Text(key.story)
                    .font(Typography.secondary)
                    .foregroundStyle(Color.mutedInk)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
