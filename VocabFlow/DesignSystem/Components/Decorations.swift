import SwiftUI

struct BrandBar: View {
    var body: some View {
        HStack(spacing: Spacing.xs) {
            RoundedRectangle(cornerRadius: Radii.chip, style: .continuous)
                .fill(Color.primaryAction)
                .frame(width: 36, height: 36)
                .overlay(
                    Image(systemName: "sparkle")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.white)
                )
                .rotationEffect(.degrees(-6))
            Text(wordmark)
                .font(Typography.wordmark)
                .tracking(-0.7)
            Spacer()
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: "Vocab Flow"))
        .accessibilityAddTraits(.isHeader)
    }

    private var wordmark: AttributedString {
        var vocab = AttributedString("vocab")
        vocab.foregroundColor = Color.ink
        var flow = AttributedString("flow")
        flow.foregroundColor = Color.primaryAction
        var dot = AttributedString(".")
        dot.foregroundColor = Color.mint
        return vocab + flow + dot
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
                    accent.frame(height: Spacing.xs)
                }
            }
            .clipShape(shape)
            .overlay(shape.strokeBorder(Color.stroke))
    }
}

extension View {
    func cardSurface(radius: CGFloat = Radii.card, fill: Color = .surface, accent: Color? = nil) -> some View {
        modifier(CardSurface(radius: radius, fill: fill, accent: accent))
    }
}
