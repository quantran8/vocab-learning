import SwiftUI

/// Sheet editing only the routine (daily goal, reviews per session, learning days, reminder); topics are untouched.
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
                    reviewsSection
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
            saveBar
        }
    }

    private var reviewsSection: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            PlanSectionTitle(text: "Reviews / session")
            WordsPerDayStepper(
                value: draft.effectiveReviewsPerSession,
                range: LearningPreferences.reviewsPerSessionRange,
                label: "Reviews per session",
                decreaseLabel: "Decrease reviews per session",
                increaseLabel: "Increase reviews per session"
            ) { amount in
                draft.adjustReviewsPerSession(by: amount)
                settings.feedback.selectionChanged()
            }
            HStack(alignment: .firstTextBaseline, spacing: Spacing.s) {
                Group {
                    if draft.reviewsPerSession == nil {
                        Text("Follows your new words, at least \(LearningPreferences.reviewsPerSessionRange.lowerBound).")
                    } else {
                        Text("Words due for review wait for the next session.")
                    }
                }
                .font(Typography.micro)
                .foregroundStyle(Color.mutedInk)
                .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
                if draft.reviewsPerSession != nil {
                    Button {
                        draft.reviewsPerSession = nil
                        settings.feedback.selectionChanged()
                    } label: {
                        Text("Match new words")
                            .font(Typography.micro.weight(.heavy))
                            .foregroundStyle(Color.selectedInk)
                            .frame(minHeight: Spacing.minTouchTarget)
                    }
                }
            }
        }
    }

    private var saveBar: some View {
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
