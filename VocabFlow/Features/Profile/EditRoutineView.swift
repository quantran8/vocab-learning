import SwiftUI

/// Sheet editing only the routine (daily goal, learning days, reminder); topics are untouched.
/// Dismissing discards the draft.
struct EditRoutineView: View {
    let onSave: (LearningPreferences) -> Void
    @Environment(AppSettingsStore.self) private var settings
    @State private var draft: LearningPreferences

    init(initial: LearningPreferences, onSave: @escaping (LearningPreferences) -> Void) {
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

                PunctuatedTitle(text: "Your routine")
                    .padding(.top, Spacing.xs)
                    .padding(.bottom, Spacing.xl - 2)

                VStack(alignment: .leading, spacing: Spacing.xl - 1) {
                    VStack(alignment: .leading, spacing: Spacing.s) {
                        PlanSectionTitle(text: "New words / day")
                        WordsPerDayStepper(value: draft.wordsPerDay) { amount in
                            draft.adjustWordsPerDay(by: amount)
                            settings.feedback.selectionChanged()
                        }
                    }
                    LearningDaysPicker(
                        selected: draft.learningDays,
                        onToggleDay: { day in
                            draft.toggleDay(day)
                            settings.feedback.selectionChanged()
                        },
                        onToggleEveryDay: {
                            draft.toggleEveryDay()
                            settings.feedback.selectionChanged()
                        }
                    )
                    ReminderPicker(preferences: $draft)
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
                    requirement: "Choose at least one learning day",
                    isEnabled: draft.isComplete
                ) {
                    settings.feedback.success()
                    onSave(draft)
                }
            }
        }
    }
}
