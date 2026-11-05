import SwiftUI

/// Bottom sheet choosing the app's language. Picking one closes the sheet; the host applies it after,
/// because applying rebuilds the whole screen, sheet included.
struct LanguageSheet: View {
    let selected: AppLanguage
    let onSelect: (AppLanguage) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.m) {
                HStack {
                    PunctuatedTitle(text: "Choose your language", font: Typography.screenTitle)
                    Spacer(minLength: Spacing.xs)
                    SheetCloseButton()
                }

                VStack(spacing: Spacing.s) {
                    ForEach(AppLanguage.allCases) { language in
                        LanguageRow(language: language, isSelected: language == selected) {
                            onSelect(language)
                        }
                    }
                }
            }
            .padding(.horizontal, Spacing.screenGutter)
            .padding(.top, Spacing.m)
            .padding(.bottom, Spacing.l)
        }
        .presentationDetents([.height(270)])
        .presentationDragIndicator(.visible)
        .presentationBackground(Color.canvas)
    }
}
