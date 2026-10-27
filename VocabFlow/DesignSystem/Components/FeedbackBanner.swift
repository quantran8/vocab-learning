import SwiftUI

enum FeedbackKind: Equatable {
    case success, error, info
}

struct FeedbackBanner: View {
    let kind: FeedbackKind
    let title: String
    let message: String

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            Label {
                Text(title)
            } icon: {
                Image(systemName: icon)
            }
            .font(Typography.emphasis)
            Text(message)
                .font(Typography.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .foregroundStyle(foreground)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.m)
        .background(background, in: RoundedRectangle(cornerRadius: Radii.tile, style: .continuous))
        .accessibilityElement(children: .combine)
        .onAppear { announce() }
        .onChange(of: title + message) { announce() }
    }

    private func announce() {
        AccessibilityNotification.Announcement("\(title). \(message)").post()
    }

    private var icon: String {
        switch kind {
        case .success: "checkmark.circle.fill"
        case .error: "xmark.circle.fill"
        case .info: "lightbulb.fill"
        }
    }

    private var foreground: Color {
        switch kind {
        case .success: .successInk
        case .error: .errorInk
        case .info: .primarySoftInk
        }
    }

    private var background: Color {
        switch kind {
        case .success: .successSurface
        case .error: .errorSurface
        case .info: .primarySoft
        }
    }
}
