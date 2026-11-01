import SwiftUI

/// Sheet changing the English level. Dismissing discards the draft.
struct EditLevelView: View {
    let onSave: (CEFRLevel) -> Void
    @Environment(AppSettingsStore.self) private var settings
    @Environment(\.motion) private var motion
    private let initial: CEFRLevel?
    @State private var draft: CEFRLevel?

    init(initial: CEFRLevel?, onSave: @escaping (CEFRLevel) -> Void) {
        self.initial = initial
        self.onSave = onSave
        _draft = State(initialValue: initial)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Eyebrow(text: "Learning plan")
                    Spacer()
                    SheetCloseButton()
                }

                PunctuatedTitle(text: "Your level")
                    .padding(.top, Spacing.xs)
                    .padding(.bottom, Spacing.l - 4)

                LazyVGrid(columns: [GridItem(.flexible(), spacing: Spacing.s), GridItem(.flexible())], spacing: Spacing.s) {
                    ForEach(CEFRLevel.allCases) { level in
                        Button {
                            guard level != draft else { return }
                            motion.perform(MotionTokens.snap) { draft = level }
                            settings.feedback.selectionChanged()
                        } label: {
                            WordTile(text: level.rawValue, visualState: draft == level ? .selected : .idle)
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(draft == level ? .isSelected : [])
                    }
                }
            }
            .padding(.horizontal, Spacing.screenGutter)
            .padding(.top, Spacing.l)
            .padding(.bottom, Spacing.l)
        }
        .safeAreaInset(edge: .bottom) {
            PinnedActionBar {
                PrimaryButton(
                    title: "Save changes",
                    requirement: "Choose your level",
                    isEnabled: draft != nil && draft != initial
                ) {
                    guard let draft else { return }
                    settings.feedback.success()
                    onSave(draft)
                }
            }
        }
    }
}
