import SwiftUI

struct ProfileView: View {
    let onEditLevel: () -> Void
    let onEditFocus: () -> Void
    let onEditRoutine: () -> Void
    let onOpenSettings: () -> Void
    @Environment(LearningPlanStore.self) private var plan
    @Environment(LearnerStore.self) private var learner

    var body: some View {
        let preferences = plan.current

        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Eyebrow(text: "Profile")
                    Spacer()
                    Button(action: onOpenSettings) {
                        SystemBarButtonLabel(systemImage: "gearshape")
                    }
                    .buttonStyle(PressScaleButtonStyle())
                    .accessibilityLabel(Text("Settings"))
                }

                identity
                    .padding(.top, Spacing.l - 1)

                Rectangle()
                    .fill(Color.neutralSurface)
                    .frame(height: 1)
                    .padding(.vertical, Spacing.l - 2)

                levelSection
                    .padding(.bottom, Spacing.l - 1)

                focusSection(preferences)

                routineSection(preferences)
                    .padding(.top, Spacing.l - 1)
            }
            .padding(.horizontal, Spacing.screenGutter)
            .padding(.top, Spacing.m)
            .padding(.bottom, Spacing.l)
        }
    }

    private var identity: some View {
        let name = String(localized: "Learner", bundle: .appLanguage)
        return HStack(spacing: Spacing.s) {
            RoundedRectangle(cornerRadius: Radii.card, style: .continuous)
                .fill(Color.selectedSurface)
                .frame(width: 60, height: 60)
                .overlay(
                    Text(verbatim: String(name.prefix(1)))
                        .font(Typography.challengeTerm)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                        .foregroundStyle(Color.selectedInk)
                )
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(verbatim: name)
                    .font(.system(.title2, weight: .heavy))
                    .tracking(-1.1)
                    .foregroundStyle(Color.ink)
                    .accessibilityAddTraits(.isHeader)
                Text("My learning space")
                    .font(Typography.micro)
                    .foregroundStyle(Color.mutedInk)
            }
        }
    }

    private var levelSection: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            sectionHeader("Your level", editLabel: "Edit level", action: onEditLevel)
            VStack(spacing: 0) {
                dataRow("chart.bar", label: "English level", value: learner.profile?.proficiencyLevel.map { Text(verbatim: $0.rawValue) } ?? Text("Not set"))
            }
            .padding(.horizontal, Spacing.m)
            .padding(.vertical, Spacing.xxs)
            .cardSurface(radius: Radii.card - 2)
        }
    }

    /// Topics shown before collapsing the rest into "+N more".
    private static let visibleTopicLimit = 4

    private func focusSection(_ preferences: LearningPreferences) -> some View {
        let topics = TopicCatalog.topics(ids: preferences.topicIDs)
        let hidden = max(0, topics.count - Self.visibleTopicLimit)
        return VStack(alignment: .leading, spacing: Spacing.s) {
            sectionHeader("Your focus", editLabel: "Edit focus", action: onEditFocus)
            if let collection = preferences.collection {
                Eyebrow(text: LocalizedStringKey(collection.name))
            }
            FlowLayout(spacing: Spacing.xs, lineSpacing: Spacing.xs, alignment: .leading) {
                ForEach(topics.prefix(Self.visibleTopicLimit)) { topic in
                    Label {
                        Text(verbatim: topic.name)
                    } icon: {
                        Image(systemName: topic.systemImage)
                    }
                    .font(Typography.micro.weight(.semibold))
                    .foregroundStyle(Color.ink)
                    .padding(.horizontal, Spacing.s)
                    .padding(.vertical, Spacing.s - 2)
                    .overlay(Capsule().strokeBorder(Color.stroke, lineWidth: 1.5))
                }
                if hidden > 0 {
                    Button(action: onEditFocus) {
                        Text("+\(hidden) more")
                            .font(Typography.micro.weight(.bold))
                            .foregroundStyle(Color.selectedInk)
                            .padding(.horizontal, Spacing.s)
                            .padding(.vertical, Spacing.s - 2)
                            .background(Color.selectedSurface, in: Capsule())
                    }
                    .buttonStyle(PressScaleButtonStyle())
                    .accessibilityHint(Text("Shows all topics"))
                }
            }
        }
    }

    private func routineSection(_ preferences: LearningPreferences) -> some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            sectionHeader("Your routine", editLabel: "Edit routine", action: onEditRoutine)
            VStack(spacing: 0) {
                dataRow("book", label: "New words / day", value: Text("\(preferences.wordsPerDay) words"))
                Divider().overlay(Color.neutralSurface)
                dataRow("calendar", label: "Learning days", value: Text(verbatim: daysSummary(preferences)))
                Divider().overlay(Color.neutralSurface)
                dataRow("bell", label: "Reminder", value: preferences.reminderEnabled
                    ? Text(preferences.reminderDate, format: .dateTime.hour().minute())
                    : Text("Off"))
            }
            .padding(.horizontal, Spacing.m)
            .padding(.vertical, Spacing.xxs)
            .cardSurface(radius: Radii.card - 2)
        }
    }

    private func sectionHeader(_ title: LocalizedStringKey, editLabel: LocalizedStringKey, action: @escaping () -> Void) -> some View {
        HStack {
            PlanSectionTitle(text: title)
            Spacer()
            Button(action: action) {
                Text("Edit")
                    .font(Typography.micro.weight(.heavy))
                    .foregroundStyle(Color.selectedInk)
                    .frame(minHeight: Spacing.minTouchTarget)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel(Text(editLabel))
        }
        .padding(.bottom, -Spacing.xs)
    }

    private func dataRow(_ systemImage: String, label: LocalizedStringKey, value: Text) -> some View {
        HStack(spacing: Spacing.s) {
            Label {
                Text(label)
            } icon: {
                Image(systemName: systemImage)
                    .foregroundStyle(Color.mutedInk)
            }
            .font(Typography.secondary.weight(.semibold))
            .foregroundStyle(Color.ink)
            Spacer(minLength: Spacing.s)
            value
                .font(Typography.secondary.weight(.heavy))
                .foregroundStyle(Color.ink)
                .multilineTextAlignment(.trailing)
        }
        .frame(minHeight: 54)
        .accessibilityElement(children: .combine)
    }

    private func daysSummary(_ preferences: LearningPreferences) -> String {
        if preferences.isEveryDay { return String(localized: "Every day", bundle: .appLanguage) }
        return Weekday.ordered
            .filter { preferences.learningDays.contains($0.id) }
            .map(\.short)
            .formatted(.list(type: .and, width: .narrow).locale(AppLanguage.active.locale))
    }
}
