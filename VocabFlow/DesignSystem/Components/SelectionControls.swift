import SwiftUI

/// Large title ending in the brand's blue full stop ("Your routine.").
struct PunctuatedTitle: View {
    let text: LocalizedStringKey
    var font: Font = Typography.display

    var body: some View {
        (Text(text) + Text(verbatim: ".").foregroundStyle(Color.interactive))
            .font(font)
            .tracking(-1.2)
            .foregroundStyle(Color.ink)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityAddTraits(.isHeader)
    }
}

/// Back button plus an optional segmented step indicator, for short linear flows.
struct StepHeader: View {
    var step: Int?
    var totalSteps = 2
    let backLabel: LocalizedStringKey
    let onBack: () -> Void
    @Environment(\.motion) private var motion

    var body: some View {
        HStack {
            Button(action: onBack) {
                Image(systemName: "arrow.left")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Color.ink)
                    .frame(width: Spacing.minTouchTarget, height: Spacing.minTouchTarget)
                    .overlay(
                        RoundedRectangle(cornerRadius: Radii.tile, style: .continuous)
                            .strokeBorder(Color.stroke, lineWidth: 1.5)
                    )
                    .contentShape(Rectangle())
            }
            .buttonStyle(PressScaleButtonStyle())
            .accessibilityLabel(Text(backLabel))

            Spacer()

            if let step {
                HStack(spacing: Spacing.xs) {
                    Text(verbatim: "\(step) / \(totalSteps)")
                        .font(Typography.micro.weight(.bold).monospacedDigit())
                        .foregroundStyle(Color.mutedInk)
                        .padding(.trailing, Spacing.xxs)
                    ForEach(1...max(totalSteps, 1), id: \.self) { index in
                        Capsule()
                            .fill(index <= step ? Color.interactive : Color.track)
                            .frame(width: 36, height: 6)
                    }
                }
                .animation(motion.animation(MotionTokens.progress), value: step)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text("Step \(step) of \(totalSteps)"))
            }
        }
    }
}

/// Pill toggle with a leading icon. Selection is shown by colour and border, never a checkmark.
struct TopicChip: View {
    let title: String
    let systemImage: String
    let isSelected: Bool
    let action: () -> Void
    @Environment(\.motion) private var motion

    var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.xs - 1) {
                Image(systemName: systemImage)
                    .font(.subheadline.weight(.medium))
                    .accessibilityHidden(true)
                Text(verbatim: title)
                    .font(Typography.secondary.weight(.semibold))
                    .lineLimit(1)
            }
            .foregroundStyle(isSelected ? Color.selectedInk : Color.ink)
            .padding(.leading, Spacing.s - 1)
            .padding(.trailing, Spacing.s + 1)
            .frame(minHeight: Spacing.minTouchTarget)
            .background(isSelected ? Color.selectedSurface : Color.surface, in: Capsule())
            .overlay(Capsule().strokeBorder(isSelected ? Color.interactive : Color.stroke, lineWidth: 1.5))
            .contentShape(Capsule())
            .animation(motion.animation(MotionTokens.press), value: isSelected)
        }
        .buttonStyle(PressScaleButtonStyle())
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

/// Fixed-size square toggle used for weekday pickers.
struct DayToggle: View {
    let title: String
    let accessibilityName: String
    let isSelected: Bool
    let action: () -> Void
    @Environment(\.motion) private var motion

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: Radii.tile - 1, style: .continuous)
        Button(action: action) {
            Text(verbatim: title)
                .font(Typography.micro.weight(.bold))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .foregroundStyle(isSelected ? Color.selectedInk : Color.mutedInk)
                .frame(maxWidth: .infinity, minHeight: 50)
                .background(isSelected ? Color.selectedSurface : Color.surface, in: shape)
                .overlay(shape.strokeBorder(isSelected ? Color.interactive : Color.stroke, lineWidth: isSelected ? 2 : 1.5))
                .contentShape(shape)
                .animation(motion.animation(MotionTokens.press), value: isSelected)
        }
        .buttonStyle(PressScaleButtonStyle())
        .accessibilityLabel(Text(verbatim: accessibilityName))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

struct SearchField: View {
    let placeholder: LocalizedStringKey
    @Binding var text: String
    @FocusState private var isFocused: Bool

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: Radii.tile, style: .continuous)
        HStack(spacing: Spacing.s - 2) {
            Image(systemName: "magnifyingglass")
                .font(.body.weight(.medium))
                .foregroundStyle(Color.mutedInk)
                .accessibilityHidden(true)
            TextField(placeholder, text: $text)
                .font(Typography.body)
                .foregroundStyle(Color.ink)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.search)
                .focused($isFocused)
            if !text.isEmpty {
                Button {
                    text = ""
                    isFocused = true
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Color.mutedInk)
                        .frame(width: Spacing.minTouchTarget - 12, height: Spacing.minTouchTarget - 12)
                }
                .accessibilityLabel(Text("Clear search"))
            }
        }
        .padding(.horizontal, Spacing.m - 2)
        .frame(minHeight: Spacing.minTouchTarget + 4)
        .background(Color.surface, in: shape)
        .overlay(shape.strokeBorder(isFocused ? Color.focusRing : Color.stroke, lineWidth: isFocused ? 2 : 1.5))
        .contentShape(shape)
        .onTapGesture { isFocused = true }
    }
}

struct PressScaleButtonStyle: ButtonStyle {
    @Environment(\.motion) private var motion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? motion.pressedScale : 1)
            .animation(motion.animation(MotionTokens.press), value: configuration.isPressed)
    }
}

/// Round ✕ for sheets, sized to a full touch target. Dismisses the presenting sheet.
struct SheetCloseButton: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Button {
            dismiss()
        } label: {
            Image(systemName: "xmark")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(Color.mutedInk)
                .frame(width: 34, height: 34)
                .background(Color.neutralSurface, in: Circle())
                .frame(width: Spacing.minTouchTarget, height: Spacing.minTouchTarget)
                .contentShape(Rectangle())
        }
        .buttonStyle(PressScaleButtonStyle())
        .padding(.trailing, -Spacing.xs)
        .accessibilityLabel(Text("Close"))
    }
}
