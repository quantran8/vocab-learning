import SwiftUI

/// Sheet editing only the topic selection; the routine is untouched. Dismissing discards the draft.
struct EditFocusView: View {
    let onSave: (LearningPreferences) -> Void
    @Environment(AppSettingsStore.self) private var settings
    @State private var draft: LearningPreferences
    @State private var browser: TopicBrowserState

    init(initial: LearningPreferences, onSave: @escaping (LearningPreferences) -> Void) {
        self.onSave = onSave
        _draft = State(initialValue: initial)
        _browser = State(initialValue: TopicBrowserState(selected: initial.topicIDs))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Eyebrow(text: "Learning plan")
                    Spacer()
                    SheetCloseButton()
                }

                PunctuatedTitle(text: "Your focus")
                    .padding(.top, Spacing.xs)
                    .padding(.bottom, Spacing.l - 4)

                TopicPicker(browser: $browser, selectedIDs: draft.topicIDs) { id in
                    draft.toggleTopic(id)
                    settings.feedback.selectionChanged()
                }
            }
            .padding(.horizontal, Spacing.screenGutter)
            .padding(.top, Spacing.l)
            .padding(.bottom, Spacing.l)
        }
        .scrollDismissesKeyboard(.interactively)
        .safeAreaInset(edge: .bottom) {
            PinnedActionBar {
                VStack(spacing: Spacing.s) {
                    if !draft.topicIDs.isEmpty {
                        Text("\(draft.topicIDs.count) topics selected")
                            .font(Typography.micro.weight(.semibold))
                            .foregroundStyle(Color.mutedInk)
                            .contentTransition(.numericText())
                    }
                    PrimaryButton(
                        title: "Save changes",
                        requirement: "Choose at least one topic",
                        isEnabled: draft.isComplete
                    ) {
                        settings.feedback.success()
                        onSave(draft)
                    }
                }
            }
        }
    }
}
