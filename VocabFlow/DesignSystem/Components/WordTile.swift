import SwiftUI

enum WordTileVisualState: Equatable {
    case idle, pressed, dragging, selected, correct, incorrect, disabled
}

struct WordTile: View {
    let text: String
    let visualState: WordTileVisualState
    @Environment(\.motion) private var motion

    var body: some View {
        HStack(spacing: Spacing.xs) {
            if let icon {
                Image(systemName: icon)
                    .accessibilityHidden(true)
            }
            Text(text)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .font(Typography.tile)
        .foregroundStyle(foreground)
        .padding(.horizontal, Spacing.s)
        .padding(.vertical, Spacing.m)
        .frame(maxWidth: .infinity, minHeight: Spacing.tileMinHeight)
        .background(face, in: shape)
        .overlay(shape.strokeBorder(border, lineWidth: borderWidth))
        .offset(y: faceDrop)
        .background(shape.fill(depth).offset(y: Spacing.tileDepth))
        .padding(.bottom, Spacing.tileDepth)
        .shadow(
            color: visualState == .dragging ? Color.ink.opacity(0.18) : .clear,
            radius: visualState == .dragging ? 14 : 0,
            y: visualState == .dragging ? 10 : 0
        )
        .scaleEffect(scale)
        .opacity(visualState == .disabled ? 0.45 : 1)
        .contentShape(shape)
        .animation(motion.animation(visualState == .pressed ? MotionTokens.press : MotionTokens.lift), value: visualState)
    }

    private var shape: RoundedRectangle { RoundedRectangle(cornerRadius: Radii.tile, style: .continuous) }

    private var icon: String? {
        switch visualState {
        case .correct: "checkmark.circle.fill"
        case .incorrect: "xmark.circle.fill"
        default: nil
        }
    }

    private var faceDrop: CGFloat {
        switch visualState {
        case .pressed: Spacing.tileDepth - 1
        case .selected: 1
        default: 0
        }
    }

    private var scale: CGFloat {
        switch visualState {
        case .pressed: motion.pressedScale
        case .dragging: motion.liftedScale
        default: 1
        }
    }

    private var foreground: Color {
        switch visualState {
        case .correct: .successInk
        case .incorrect: .errorInk
        case .selected, .dragging: .primarySoftInk
        case .disabled: .mutedInk
        default: .ink
        }
    }

    private var face: Color {
        switch visualState {
        case .selected, .dragging: .selectedSurface
        case .correct: .successSurface
        case .incorrect: .errorSurface
        default: .surface
        }
    }

    private var depth: Color {
        switch visualState {
        case .selected: .selectedDepth
        case .dragging: .clear
        case .correct: .successDepth
        case .incorrect: .errorDepth
        default: .tileDepth
        }
    }

    private var border: Color {
        switch visualState {
        case .selected, .dragging: .primaryAction
        case .correct: .successInk
        case .incorrect: .errorInk
        default: .stroke
        }
    }

    private var borderWidth: CGFloat {
        switch visualState {
        case .selected, .dragging, .correct, .incorrect: 2
        default: 1.5
        }
    }
}

#Preview {
    VStack(spacing: Spacing.s) {
        WordTile(text: "appreciate", visualState: .idle)
        WordTile(text: "appreciate", visualState: .pressed)
        WordTile(text: "appreciate", visualState: .selected)
        WordTile(text: "appreciate", visualState: .dragging)
        WordTile(text: "appreciate", visualState: .correct)
        WordTile(text: "arrive", visualState: .incorrect)
        WordTile(text: "belong", visualState: .disabled)
    }
    .padding()
    .background(Color.canvas)
}
