import SwiftUI

/// The first screen after the first login. Shows itself in the highlighted language,
/// so the choice can be read before it is confirmed.
struct LanguageSelectionView: View {
    @Environment(AppSettingsStore.self) private var settings
    @Environment(\.motion) private var motion
    @State private var selection = AppLanguage.device

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                BrandBar()

                PunctuatedTitle(text: "Choose your language")
                    .padding(.top, Spacing.xl)

                Text("You can change this anytime in Settings.")
                    .font(Typography.body.weight(.medium))
                    .foregroundStyle(Color.mutedInk)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, Spacing.s)

                VStack(spacing: Spacing.s) {
                    ForEach(AppLanguage.allCases) { language in
                        LanguageRow(language: language, isSelected: language == selection) {
                            motion.perform(MotionTokens.press) { selection = language }
                        }
                    }
                }
                .padding(.top, Spacing.l)
            }
            .padding(.horizontal, Spacing.screenGutter)
            .padding(.top, Spacing.s)
            .padding(.bottom, Spacing.l)
        }
        .safeAreaInset(edge: .bottom) {
            PinnedActionBar {
                PrimaryButton(title: "Continue") {
                    motion.perform(MotionTokens.transition) { settings.chooseLanguage(selection) }
                }
            }
        }
        .environment(\.locale, selection.locale)
    }
}

/// Selection is shown by colour and border, never a checkmark, like the other selection controls.
struct LanguageRow: View {
    let language: AppLanguage
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: Radii.tile, style: .continuous)
        Button(action: action) {
            Text(verbatim: language.nativeName)
                .font(Typography.body.weight(.semibold))
                .foregroundStyle(isSelected ? Color.selectedInk : Color.ink)
                .frame(maxWidth: .infinity, minHeight: Spacing.minTouchTarget + 12, alignment: .leading)
                .padding(.horizontal, Spacing.m)
                .background(isSelected ? Color.selectedSurface : Color.surface, in: shape)
                .overlay(shape.strokeBorder(isSelected ? Color.interactive : Color.stroke, lineWidth: isSelected ? 2 : 1.5))
                .contentShape(shape)
        }
        .buttonStyle(PressScaleButtonStyle())
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
