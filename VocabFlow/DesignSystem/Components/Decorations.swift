import SwiftUI

struct BrandBar: View {
    var body: some View {
        HStack(spacing: Spacing.xs) {
            // A downscaled copy of the app icon: an `.appiconset` can't be loaded as an image.
            Image("BrandIcon")
                .resizable()
                .interpolation(.high)
                .frame(width: 34, height: 34)
                .clipShape(RoundedRectangle(cornerRadius: Radii.chip, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: Radii.chip, style: .continuous)
                        .strokeBorder(Color.stroke, lineWidth: 1)
                )
            Text(verbatim: "syll")
                .font(Typography.wordmark)
                .tracking(-0.6)
                .foregroundStyle(Color.ink)
            Spacer()
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: "Syll"))
        .accessibilityAddTraits(.isHeader)
    }
}

struct CardSurface: ViewModifier {
    var radius: CGFloat = Radii.card
    var fill: Color = .surface
    var accent: Color?

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        content
            .frame(maxWidth: .infinity)
            .background(fill)
            .overlay(alignment: .top) {
                if let accent {
                    accent.frame(height: Spacing.xxs + 2)
                }
            }
            .clipShape(shape)
            .overlay(shape.strokeBorder(Color.stroke, lineWidth: 2))
    }
}

extension View {
    func cardSurface(radius: CGFloat = Radii.card, fill: Color = .surface, accent: Color? = nil) -> some View {
        modifier(CardSurface(radius: radius, fill: fill, accent: accent))
    }
}

/// Small pill used for category markers and decorative highlights. Never a real score.
struct Chip: View {
    let text: LocalizedStringKey
    var fill: Color = .neutralSurface
    var foreground: Color = .ink

    var body: some View {
        Text(text)
            .font(Typography.eyebrow)
            .tracking(0.4)
            .textCase(.uppercase)
            .foregroundStyle(foreground)
            .padding(.horizontal, Spacing.s - 2)
            .padding(.vertical, Spacing.xxs + 1)
            .background(fill, in: Capsule())
    }
}
