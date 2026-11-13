import SwiftUI

/// A learner's chosen avatar from the server allowlist. Stand-in art until the Syllie set is drawn.
struct AvatarView: View {
    let key: String
    var size: CGFloat = 44
    /// Nil draws a circle.
    var cornerRadius: CGFloat? = nil

    var body: some View {
        let shape = cornerRadius.map { AnyShape(RoundedRectangle(cornerRadius: $0, style: .continuous)) } ?? AnyShape(Circle())
        shape
            .fill(AvatarStyle.background(key))
            .frame(width: size, height: size)
            .overlay(
                Image(systemName: AvatarStyle.symbol(key))
                    .font(.system(size: size * 0.4, weight: .bold))
                    .foregroundStyle(Color.ink)
            )
            .overlay(shape.stroke(Color.stroke.opacity(0.6), lineWidth: 1))
            .accessibilityHidden(true)
    }
}

/// Profile's Tier card: current Tier and the LP still to go to the next one. Learning days stay on the detail screen.
struct ProfileTierCard: View {
    let summary: TierSummary
    var next: NextTier?

    private var key: TierKey? { summary.level > 0 ? summary.key : nil }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            HStack(spacing: Spacing.s) {
                RoundedRectangle(cornerRadius: Radii.tile, style: .continuous)
                    .fill(key == nil ? Color.neutralSurface : Color.reward)
                    .frame(width: 52, height: 52)
                    .overlay(
                        Image(systemName: key?.systemImage ?? "leaf")
                            .font(.title3.weight(.bold))
                            .foregroundStyle(Color.ink)
                    )
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Eyebrow(text: "Current Tier")
                    Group {
                        if let key { Text(key.name) } else { Text("No Tier yet") }
                    }
                    .font(Typography.tileLarge.weight(.bold))
                    .foregroundStyle(Color.ink)
                }
                Spacer(minLength: 0)
            }
            if let next {
                Divider().overlay(Color.neutralSurface)
                VStack(alignment: .leading, spacing: Spacing.s) {
                    HStack(alignment: .firstTextBaseline) {
                        Text("Progress to \((next.key ?? .unknown).localizedName)")
                            .font(Typography.secondary.weight(.bold))
                            .foregroundStyle(Color.ink)
                        Spacer(minLength: Spacing.xs)
                        Text("\(min(summary.lifetimeLP, next.minLifetimeLP)) / \(next.minLifetimeLP) LP")
                            .font(Typography.micro.weight(.bold).monospacedDigit())
                            .foregroundStyle(Color.mutedInk)
                    }
                    ProgressTrack(fraction: next.minLifetimeLP > 0
                                  ? CGFloat(min(Double(summary.lifetimeLP) / Double(next.minLifetimeLP), 1)) : 1)
                }
            } else if key != nil {
                Divider().overlay(Color.neutralSurface)
                Text("You’ve reached the highest Tier. Your LP and learning days keep adding up.")
                    .font(Typography.micro)
                    .foregroundStyle(Color.mutedInk)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(Spacing.m)
        .cardSurface(radius: Radii.card)
        .accessibilityElement(children: .combine)
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
