import SwiftUI

/// A learner's chosen avatar from the server allowlist. Stand-in art until the Syllie set is drawn.
struct AvatarView: View {
    let key: String
    var size: CGFloat = 44

    var body: some View {
        Circle()
            .fill(AvatarStyle.background(key))
            .frame(width: size, height: size)
            .overlay(
                Image(systemName: AvatarStyle.symbol(key))
                    .font(.system(size: size * 0.42, weight: .bold))
                    .foregroundStyle(Color.ink)
            )
            .overlay(Circle().strokeBorder(Color.stroke, lineWidth: 1.5))
            .accessibilityHidden(true)
    }
}

/// Small lifetime-Tier marker for a leaderboard row. Level 0 shows nothing: there is no "Tier 0".
struct TierBadgeLabel: View {
    let badge: TierBadge

    var body: some View {
        if let key = badge.key, badge.level > 0 {
            Label {
                Text(key.name)
            } icon: {
                Image(systemName: key.systemImage)
            }
            .font(Typography.micro.weight(.semibold))
            .foregroundStyle(Color.mutedInk)
            .labelStyle(.titleAndIcon)
        }
    }
}

/// The Tier's name, story and evidence; spec §3.5. `next` adds the two independent progress bars.
struct TierCard: View {
    let summary: TierSummary
    var next: NextTier?
    var showsChevron = false
    @Environment(\.motion) private var motion

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            HStack(alignment: .top, spacing: Spacing.s) {
                emblem
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Eyebrow(text: "Lifetime achievement")
                    title
                        .font(Typography.screenTitle)
                        .foregroundStyle(Color.ink)
                    story
                        .font(Typography.secondary)
                        .foregroundStyle(Color.mutedInk)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                if showsChevron {
                    Image(systemName: "chevron.right")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(Color.mutedInk)
                        .accessibilityHidden(true)
                }
            }
            HStack(spacing: Spacing.s) {
                evidence(Text("\(summary.lifetimeLP) LP earned"), systemImage: "bolt.fill")
                evidence(Text("\(summary.lifetimeActiveDays) learning days"), systemImage: "calendar")
            }
            if let next {
                TierProgress(summary: summary, next: next)
            } else if summary.level > 0, summary.key != nil {
                Text("You’ve reached the highest Tier. Your LP and learning days keep adding up.")
                    .font(Typography.micro)
                    .foregroundStyle(Color.mutedInk)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(Spacing.m)
        .cardSurface(radius: Radii.card - 2, accent: summary.level > 0 ? .reward : nil)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityText)
    }

    private var key: TierKey? { summary.level > 0 ? summary.key : nil }

    private var emblem: some View {
        RoundedRectangle(cornerRadius: Radii.tile, style: .continuous)
            .fill(key == nil ? Color.neutralSurface : Color.reward)
            .frame(width: 56, height: 56)
            .overlay(
                Image(systemName: key?.systemImage ?? "leaf")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(Color.ink)
            )
            .accessibilityHidden(true)
    }

    private var title: Text {
        key.map { Text($0.name) } ?? Text("No Tier yet")
    }

    private var story: Text {
        key.map { Text($0.story) } ?? Text("Learn on a few days to unlock your first milestone.")
    }

    private func evidence(_ text: Text, systemImage: String) -> some View {
        Label { text } icon: { Image(systemName: systemImage) }
            .font(Typography.micro.weight(.bold))
            .foregroundStyle(Color.ink)
            .padding(.horizontal, Spacing.s - 2)
            .padding(.vertical, Spacing.xxs + 2)
            .background(Color.neutralSurface, in: Capsule())
    }

    private var accessibilityText: Text {
        guard let key else {
            return Text("No Tier yet, \(summary.lifetimeLP) LP earned, \(summary.lifetimeActiveDays) learning days")
        }
        return Text("\(key.localizedName), Tier \(summary.level), \(summary.lifetimeLP) LP earned, \(summary.lifetimeActiveDays) learning days")
    }
}

/// LP and learning days toward the next Tier, side by side. Never a blended percentage, never a countdown.
struct TierProgress: View {
    let summary: TierSummary
    let next: NextTier

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            bar(Text("LP \(min(summary.lifetimeLP, next.minLifetimeLP))/\(next.minLifetimeLP)"),
                fraction: fraction(summary.lifetimeLP, next.minLifetimeLP))
            bar(Text("Learning days \(min(summary.lifetimeActiveDays, next.minLifetimeActiveDays))/\(next.minLifetimeActiveDays)"),
                fraction: fraction(summary.lifetimeActiveDays, next.minLifetimeActiveDays))
            remaining
                .font(Typography.micro)
                .foregroundStyle(Color.mutedInk)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func fraction(_ value: Int, _ goal: Int) -> CGFloat {
        goal > 0 ? CGFloat(min(Double(value) / Double(goal), 1)) : 1
    }

    private func bar(_ label: Text, fraction: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            label
                .font(Typography.micro.weight(.semibold).monospacedDigit())
                .foregroundStyle(Color.ink)
            ProgressTrack(fraction: fraction)
        }
        .accessibilityElement(children: .combine)
    }

    /// Only what is still missing (spec §10).
    private var remaining: Text {
        let lp = next.remainingLP ?? max(0, next.minLifetimeLP - summary.lifetimeLP)
        let days = next.remainingActiveDays ?? max(0, next.minLifetimeActiveDays - summary.lifetimeActiveDays)
        let name = (next.key ?? .unknown).localizedName
        switch (lp > 0, days > 0) {
        case (true, true): return Text("\(lp) more LP and \(days) more learning days to reach \(name)")
        case (true, false): return Text("\(lp) more LP to reach \(name)")
        case (false, true): return Text("\(days) more learning days to reach \(name)")
        case (false, false): return Text("Your next session unlocks \(name)")
        }
    }
}
