import SwiftUI

struct BrandBar: View {
    var body: some View {
        HStack(spacing: Spacing.xs) {
            RoundedRectangle(cornerRadius: Radii.chip, style: .continuous)
                .fill(Color.ink)
                .frame(width: 34, height: 34)
                .overlay(alignment: .bottomTrailing) {
                    Circle()
                        .fill(Color.reward)
                        .frame(width: 10, height: 10)
                        .padding(6)
                }
                .overlay(
                    Text(verbatim: "v")
                        .font(.system(size: 18, weight: .heavy))
                        .foregroundStyle(.white)
                        .offset(x: -3, y: -2)
                )
            Text(verbatim: "vocab flow")
                .font(Typography.wordmark)
                .tracking(-0.6)
                .foregroundStyle(Color.ink)
            Spacer()
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: "Vocab Flow"))
        .accessibilityAddTraits(.isHeader)
    }
}

struct DotGrid: View {
    var spacing: CGFloat = 18
    var color: Color = .dot

    var body: some View {
        Canvas { context, size in
            var path = Path()
            var y: CGFloat = spacing / 2
            while y < size.height {
                var x: CGFloat = spacing / 2
                while x < size.width {
                    path.addEllipse(in: CGRect(x: x - 1, y: y - 1, width: 2, height: 2))
                    x += spacing
                }
                y += spacing
            }
            context.fill(path, with: .color(color))
        }
        .accessibilityHidden(true)
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
            .overlay(shape.strokeBorder(Color.stroke, lineWidth: 1.5))
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
