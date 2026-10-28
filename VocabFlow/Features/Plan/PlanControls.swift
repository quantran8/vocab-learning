import SwiftUI

/// Learning-plan inputs shared by onboarding and the Profile plan editor.

/// Searchable, collapsible topic groups.
struct TopicPicker: View {
    @Binding var browser: TopicBrowserState
    let selectedIDs: Set<String>
    let onToggleTopic: (String) -> Void
    @Environment(\.motion) private var motion

    var body: some View {
        let groups = browser.visibleGroups
        VStack(alignment: .leading, spacing: 0) {
            SearchField(placeholder: "Search topics", text: $browser.query)

            if groups.isEmpty {
                Text("No topics found")
                    .font(Typography.secondary)
                    .foregroundStyle(Color.mutedInk)
                    .padding(.vertical, Spacing.l - 2)
            } else {
                ForEach(groups) { group in
                    groupSection(group)
                        .padding(.top, Spacing.s)
                }
            }
        }
    }

    private func groupSection(_ group: TopicGroup) -> some View {
        let isExpanded = browser.isExpanded(group)
        return VStack(alignment: .leading, spacing: Spacing.s - 1) {
            groupHeader(group, isExpanded: isExpanded)
            if isExpanded {
                FlowLayout(spacing: Spacing.xs, lineSpacing: Spacing.xs, alignment: .leading) {
                    ForEach(group.topics) { topic in
                        TopicChip(
                            title: topic.name,
                            systemImage: topic.systemImage,
                            isSelected: selectedIDs.contains(topic.id)
                        ) {
                            onToggleTopic(topic.id)
                        }
                    }
                }
                .transition(.opacity)
            }
        }
    }

    private func groupHeader(_ group: TopicGroup, isExpanded: Bool) -> some View {
        let selected = group.topics.filter { selectedIDs.contains($0.id) }.count
        return Button {
            motion.perform(MotionTokens.snap) { browser.toggleGroup(group.id) }
        } label: {
            HStack(spacing: Spacing.xs) {
                Eyebrow(text: LocalizedStringKey(group.name))
                    .fixedSize()
                if selected > 0 {
                    Text(verbatim: "\(selected)")
                        .font(Typography.micro.weight(.heavy).monospacedDigit())
                        .foregroundStyle(Color.selectedInk)
                        .frame(minWidth: 20, minHeight: 20)
                        .padding(.horizontal, Spacing.xxs)
                        .background(Color.selectedSurface, in: Capsule())
                        .contentTransition(.numericText(value: Double(selected)))
                        .transition(motion.popTransition)
                }
                Rectangle()
                    .fill(Color.neutralSurface)
                    .frame(height: 1)
                if !browser.isSearching {
                    Image(systemName: "chevron.down")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Color.mutedInk)
                        .rotationEffect(.degrees(isExpanded ? 0 : -90))
                }
            }
            .frame(minHeight: Spacing.minTouchTarget)
            .contentShape(Rectangle())
            .animation(motion.animation(MotionTokens.snap), value: selected)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: group.name))
        .accessibilityValue(Text("\(selected) selected"))
        .accessibilityHint(Text(isExpanded ? "Collapse" : "Expand"))
        .accessibilityAddTraits(.isHeader)
    }
}

/// − value + inside a card, clamped to `LearningPreferences.wordsPerDayRange`.
struct WordsPerDayStepper: View {
    let value: Int
    let onAdjust: (Int) -> Void
    @Environment(\.motion) private var motion

    var body: some View {
        let range = LearningPreferences.wordsPerDayRange
        HStack(spacing: Spacing.xs - 1) {
            stepperButton("minus", label: "Decrease new words per day", isEnabled: value > range.lowerBound) {
                onAdjust(-1)
            }
            HStack(alignment: .firstTextBaseline, spacing: Spacing.xs - 1) {
                Text(verbatim: "\(value)")
                    .font(.system(size: 32, weight: .heavy).monospacedDigit())
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
            .accessibilityLabel(Text("New words per day"))
            .accessibilityValue(Text("\(value) words"))
            .accessibilityAdjustableAction { direction in
                switch direction {
                case .increment: onAdjust(1)
                case .decrement: onAdjust(-1)
                @unknown default: break
                }
            }
            stepperButton("plus", label: "Increase new words per day", isEnabled: value < range.upperBound) {
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
        return (0..<7).map { offset in
            let id = (calendar.firstWeekday - 1 + offset) % 7 + 1
            return Weekday(
                id: id,
                short: calendar.shortWeekdaySymbols[id - 1],
                full: calendar.weekdaySymbols[id - 1]
            )
        }
    }
}
