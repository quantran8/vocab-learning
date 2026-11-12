import SwiftUI

/// Learning-plan inputs shared by onboarding and the Profile plan editor.

/// One CEFR level with a short plain-language name, for the level grids.
struct LevelTile: View {
    let level: CEFRLevel
    let isSelected: Bool
    let action: () -> Void

    private var summary: LocalizedStringKey {
        switch level {
        case .a1: "Beginner"
        case .a2: "Elementary"
        case .b1: "Intermediate"
        case .b2: "Upper-intermediate"
        case .c1: "Advanced"
        case .c2: "Proficient"
        }
    }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: Radii.card - 2, style: .continuous)
        Button(action: action) {
            VStack(spacing: Spacing.xxs) {
                Text(verbatim: level.rawValue)
                    .font(Typography.tileLarge.weight(.bold))
                    .foregroundStyle(isSelected ? Color.selectedInk : Color.ink)
                Text(summary)
                    .font(Typography.micro)
                    .foregroundStyle(Color.mutedInk)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, Spacing.xs)
            .padding(.vertical, Spacing.s)
            .frame(maxWidth: .infinity, minHeight: 74)
            .background(isSelected ? Color.selectedSurface : Color.surface, in: shape)
            .overlay(shape.strokeBorder(isSelected ? Color.interactive : Color.stroke, lineWidth: 1.5))
            .contentShape(shape)
        }
        .buttonStyle(PressScaleButtonStyle())
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

/// One card per collection; exactly one is selected.
struct CollectionPicker: View {
    let selectedID: String
    let onSelect: (String) -> Void

    var body: some View {
        VStack(spacing: Spacing.s - 2) {
            ForEach(TopicCatalog.collections) { collection in
                CollectionCard(collection: collection, isSelected: collection.id == selectedID) {
                    onSelect(collection.id)
                }
            }
        }
    }
}

private struct CollectionCard: View {
    let collection: VocabCollection
    let isSelected: Bool
    let action: () -> Void
    @Environment(\.motion) private var motion

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: Radii.card - 2, style: .continuous)
        Button(action: action) {
            HStack(spacing: Spacing.s) {
                Image(systemName: collection.systemImage)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(isSelected ? Color.white : Color.ink)
                    .frame(width: 48, height: 48)
                    .background(
                        isSelected ? Color.interactive : Color.neutralSurface,
                        in: RoundedRectangle(cornerRadius: Radii.tile, style: .continuous)
                    )
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: Spacing.xxs - 2) {
                    Text(verbatim: collection.name)
                        .font(Typography.emphasis)
                        .foregroundStyle(isSelected ? Color.selectedInk : Color.ink)
                    Text(verbatim: collection.summary)
                        .font(Typography.micro)
                        .foregroundStyle(Color.mutedInk)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .multilineTextAlignment(.leading)
                Spacer(minLength: 0)
                Text("\(collection.topics.count) topics")
                    .font(Typography.micro.weight(.bold).monospacedDigit())
                    .foregroundStyle(isSelected ? Color.selectedInk : Color.mutedInk)
            }
            .padding(Spacing.s)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isSelected ? Color.selectedSurface : Color.surface, in: shape)
            .overlay(shape.strokeBorder(isSelected ? Color.interactive : Color.stroke, lineWidth: isSelected ? 2 : 1.5))
            .contentShape(shape)
            .animation(motion.animation(MotionTokens.press), value: isSelected)
        }
        .buttonStyle(PressScaleButtonStyle())
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

/// The topics of one collection, with a "Select all / Clear all" shortcut.
struct TopicPicker: View {
    let collection: VocabCollection
    let selectedIDs: Set<String>
    let onToggleTopic: (String) -> Void
    let onToggleAll: () -> Void

    var body: some View {
        let hasAll = selectedIDs == collection.topicIDs
        VStack(alignment: .leading, spacing: Spacing.s) {
            HStack {
                Eyebrow(text: LocalizedStringKey(collection.name))
                Spacer()
                Button(action: onToggleAll) {
                    Text(hasAll ? "Clear all" : "Select all")
                        .font(Typography.micro.weight(.heavy))
                        .foregroundStyle(Color.selectedInk)
                        .frame(minHeight: Spacing.minTouchTarget)
                }
            }
            .padding(.bottom, -Spacing.xs)

            // Topics with new words left first; finished ones last but still selectable.
            FlowLayout(spacing: Spacing.xs, lineSpacing: Spacing.xs, alignment: .leading) {
                ForEach(collection.topics.filter { !$0.isFinished } + collection.topics.filter(\.isFinished)) { topic in
                    TopicChip(
                        title: topic.name,
                        systemImage: topic.systemImage,
                        isSelected: selectedIDs.contains(topic.id),
                        progress: topic.total.map { (learned: topic.learned ?? 0, total: $0) },
                        isFinished: topic.isFinished
                    ) {
                        onToggleTopic(topic.id)
                    }
                }
            }
        }
    }
}

/// − value + inside a card, clamped to `range`.
struct WordsPerDayStepper: View {
    let value: Int
    var range: ClosedRange<Int> = LearningPreferences.wordsPerDayRange
    var label: LocalizedStringKey = "New words per day"
    var decreaseLabel: LocalizedStringKey = "Decrease new words per day"
    var increaseLabel: LocalizedStringKey = "Increase new words per day"
    let onAdjust: (Int) -> Void
    @Environment(\.motion) private var motion

    var body: some View {
        HStack(spacing: Spacing.xs - 1) {
            stepperButton("minus", label: decreaseLabel, isEnabled: value > range.lowerBound) {
                onAdjust(-1)
            }
            HStack(alignment: .firstTextBaseline, spacing: Spacing.xs - 1) {
                Text(verbatim: "\(value)")
                    .font(Typography.display.monospacedDigit())
                    .tracking(-1.5)
                    .foregroundStyle(Color.ink)
                    .contentTransition(.numericText(value: Double(value)))
                    .animation(motion.animation(MotionTokens.snap), value: value)
                Text("words")
                    .font(Typography.micro.weight(.semibold))
                    .foregroundStyle(Color.mutedInk)
            }
            .frame(maxWidth: .infinity)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(label))
            .accessibilityValue(Text("\(value) words"))
            .accessibilityAdjustableAction { direction in
                switch direction {
                case .increment: onAdjust(1)
                case .decrement: onAdjust(-1)
                @unknown default: break
                }
            }
            stepperButton("plus", label: increaseLabel, isEnabled: value < range.upperBound) {
                onAdjust(1)
            }
        }
        .padding(Spacing.xs)
        .cardSurface(radius: Radii.card - 2)
    }

    private func stepperButton(
        _ systemImage: String,
        label: LocalizedStringKey,
        isEnabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(Color.ink)
                .frame(width: 56, height: 56)
                .background(Color.neutralSurface, in: RoundedRectangle(cornerRadius: Radii.tile - 2, style: .continuous))
        }
        .buttonStyle(PressScaleButtonStyle())
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.35)
        .accessibilityLabel(Text(label))
    }
}

/// Title row with an "Every day / Clear all" shortcut, seven day toggles and a summary line.
struct LearningDaysPicker: View {
    let selected: Set<Int>
    let onToggleDay: (Int) -> Void
    let onToggleEveryDay: () -> Void

    var body: some View {
        let isEveryDay = selected == LearningPreferences.allWeekdays
        VStack(alignment: .leading, spacing: Spacing.s) {
            HStack {
                PlanSectionTitle(text: "Learning days")
                Spacer()
                Button(action: onToggleEveryDay) {
                    Text(isEveryDay ? "Clear all" : "Every day")
                        .font(Typography.micro.weight(.heavy))
                        .foregroundStyle(Color.selectedInk)
                        .frame(minHeight: Spacing.minTouchTarget)
                }
            }
            .padding(.bottom, -Spacing.xs)

            HStack(spacing: Spacing.xxs) {
                ForEach(Weekday.ordered) { day in
                    DayToggle(
                        title: day.short,
                        accessibilityName: day.full,
                        isSelected: selected.contains(day.id)
                    ) {
                        onToggleDay(day.id)
                    }
                }
            }

            Group {
                if selected.isEmpty {
                    Text("Choose at least one day")
                } else if isEveryDay {
                    Text("Every day")
                } else {
                    Text("\(selected.count) days a week")
                }
            }
            .font(Typography.micro)
            .foregroundStyle(Color.mutedInk)
        }
    }
}

/// "Remind me" switch above a time field that dims while reminders are off.
struct ReminderPicker: View {
    @Binding var preferences: LearningPreferences
    @Environment(\.motion) private var motion

    var body: some View {
        let isOn = preferences.reminderEnabled
        let shape = RoundedRectangle(cornerRadius: Radii.tile, style: .continuous)
        VStack(alignment: .leading, spacing: Spacing.s) {
            Toggle(isOn: $preferences.reminderEnabled.animation(motion.animation(MotionTokens.press))) {
                PlanSectionTitle(text: "Remind me")
            }
            .tint(Color.interactive)

            HStack(spacing: Spacing.s - 1) {
                Image(systemName: "clock")
                    .font(.body.weight(.medium))
                    .foregroundStyle(isOn ? Color.mutedInk : Color.disabledInk)
                    .accessibilityHidden(true)
                DatePicker("Reminder time", selection: reminderTime, displayedComponents: .hourAndMinute)
                    .labelsHidden()
                    .tint(Color.interactive)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, Spacing.m - 1)
            .frame(minHeight: 57)
            .background(isOn ? Color.surface : Color.disabledSurface, in: shape)
            .overlay(shape.strokeBorder(Color.stroke, lineWidth: 1.5))
            .disabled(!isOn)
            .opacity(isOn ? 1 : 0.6)
        }
    }

    private var reminderTime: Binding<Date> {
        Binding {
            preferences.reminderDate
        } set: { date in
            let parts = Calendar.current.dateComponents([.hour, .minute], from: date)
            preferences.reminderHour = parts.hour ?? preferences.reminderHour
            preferences.reminderMinute = parts.minute ?? preferences.reminderMinute
        }
    }
}

struct PlanSectionTitle: View {
    let text: LocalizedStringKey

    var body: some View {
        Text(text)
            .font(Typography.emphasis)
            .tracking(-0.4)
            .foregroundStyle(Color.ink)
            .accessibilityAddTraits(.isHeader)
    }
}

/// Weekday labels in the user's locale, starting on the locale's first weekday.
struct Weekday: Identifiable {
    /// `Calendar` weekday number, 1 = Sunday.
    let id: Int
    let short: String
    let full: String

    static var ordered: [Weekday] {
        let calendar = Calendar.current
        var names = calendar
        names.locale = AppLanguage.active.locale
        return (0..<7).map { offset in
            let id = (calendar.firstWeekday - 1 + offset) % 7 + 1
            return Weekday(
                id: id,
                short: names.shortWeekdaySymbols[id - 1],
                full: names.weekdaySymbols[id - 1]
            )
        }
    }
}
