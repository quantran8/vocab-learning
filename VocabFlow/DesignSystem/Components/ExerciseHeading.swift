import SwiftUI

/// Left-aligned exercise title with a one-line instruction underneath.
struct ExerciseHeading: View {
    let title: Text
    var subtitle: Text?

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            title
                .font(Typography.screenTitle)
                .tracking(Typography.tightTracking)
                .foregroundStyle(Color.ink)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            if let subtitle {
                subtitle
                    .font(Typography.secondary)
                    .foregroundStyle(Color.mutedInk)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

extension ExerciseHeading {
    init(_ title: LocalizedStringKey, subtitle: LocalizedStringKey? = nil) {
        self.init(title: Text(title), subtitle: subtitle.map { Text($0) })
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
