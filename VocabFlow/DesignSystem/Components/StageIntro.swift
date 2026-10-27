import SwiftUI

struct StageIntro: View {
    let number: Int
    let label: LocalizedStringKey
    let title: String
    let subtitle: LocalizedStringKey
    var systemImage = "sparkle"

    var body: some View {
        VStack(spacing: Spacing.s) {
            HStack(spacing: Spacing.xs) {
                Image(systemName: systemImage)
                    .accessibilityHidden(true)
                Text(verbatim: String(format: "%02d ·", number))
                Text(label)
            }
            .font(Typography.eyebrow)
            .tracking(Typography.eyebrowTracking)
            .textCase(.uppercase)
            .foregroundStyle(Color.primarySoftInk)

            Text(verbatim: title)
                .font(Typography.screenTitle)
                .tracking(Typography.tightTracking)
                .foregroundStyle(Color.ink)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)

            Text(subtitle)
                .font(Typography.secondary)
                .foregroundStyle(Color.mutedInk)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }
}

struct Eyebrow: View {
    let text: LocalizedStringKey
    var color: Color = .mutedInk

    var body: some View {
        Text(text)
            .font(Typography.eyebrow)
            .tracking(Typography.eyebrowTracking)
            .textCase(.uppercase)
            .foregroundStyle(color)
    }
}
