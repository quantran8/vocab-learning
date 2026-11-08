import SwiftUI

enum FeedbackKind: Equatable {
    case success, error, info
}

struct FeedbackCopy: Equatable {
    let kind: FeedbackKind
    let title: String
    let message: String
}

/// Pinned bottom panel: explanation and primary action share one surface.
/// With feedback present, the whole panel takes the semantic status color.
struct FeedbackActionPanel<Action: View>: View {
    let feedback: FeedbackCopy?
    /// Shows Syllie beside the action, reacting with this mood. Nil hides him.
    var mascot: SyllieMood? = nil
    @ViewBuilder let action: Action
    @Environment(\.motion) private var motion

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            if let feedback {
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Label {
                        Text(feedback.title)
                    } icon: {
                        Image(systemName: icon(feedback.kind))
                            .foregroundStyle(accent(feedback.kind))
                    }
                    .font(Typography.emphasis)
                    if !feedback.message.isEmpty {
                        Text(feedback.message)
                            .font(Typography.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .foregroundStyle(ink(feedback.kind))
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityElement(children: .combine)
                .transition(motion.reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))
            }
            if let mascot {
                HStack(alignment: .bottom, spacing: Spacing.xs) {
                    // The `Syllie` artboard (520×430) leaves room around his body for the bigger gestures.
                    // Negative padding lets that margin overlap the gutter and the button, so his body sits
                    // on the gutter and close to the button; the artboard is transparent there.
                    SyllieReactionView(reaction: mascot)
                        .frame(width: 100, height: 83)
                        .padding(.leading, -7)
                        .padding(.trailing, -12)
                    action
                }
            } else {
                action
            }
        }
        .padding(.horizontal, Spacing.screenGutter)
        .padding(.top, feedback == nil ? Spacing.s : Spacing.m + 2)
        .padding(.bottom, Spacing.xs)
        .background {
            UnevenRoundedRectangle(
                topLeadingRadius: Radii.card,
                topTrailingRadius: Radii.card,
                style: .continuous
            )
            .fill(feedback.map { surface($0.kind) } ?? Color.canvas)
            .ignoresSafeArea(edges: .bottom)
        }
        .animation(motion.animation(MotionTokens.feedback), value: feedback)
        .onChange(of: feedback) { _, newValue in
            guard let newValue else { return }
            AccessibilityNotification.Announcement("\(newValue.title). \(newValue.message)").post()
        }
    }

    private func icon(_ kind: FeedbackKind) -> String {
        switch kind {
        case .success: "checkmark.circle.fill"
        case .error: "xmark.circle.fill"
        case .info: "lightbulb.fill"
        }
    }

    private func accent(_ kind: FeedbackKind) -> Color {
        switch kind {
        case .success: .success
        case .error: .error
        case .info: .interactive
        }
    }

    private func ink(_ kind: FeedbackKind) -> Color {
        switch kind {
        case .success: .successInk
        case .error: .errorInk
        case .info: .selectedInk
        }
    }

    private func surface(_ kind: FeedbackKind) -> Color {
        switch kind {
        case .success: .successSurface
        case .error: .errorSurface
        case .info: .selectedSurface
        }
    }
}
