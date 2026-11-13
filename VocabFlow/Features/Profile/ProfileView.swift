import SwiftUI

struct ProfileView: View {
    let onEditLevel: () -> Void
    let onEditFocus: () -> Void
    let onEditRoutine: () -> Void
    let onOpenSettings: () -> Void
    @Environment(LearningPlanStore.self) private var plan
    @Environment(LearnerStore.self) private var learner
    @Environment(RankingStore.self) private var ranking
    @State private var saveError: String?
    @State private var isEditingPublicProfile = false

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

                if let summary = learner.profile?.tierSummary {
                    effortSection(summary)
                        .padding(.top, Spacing.l - 1)
                }

                Rectangle()
                    .fill(Color.neutralSurface)
                    .frame(height: 1)
                    .padding(.vertical, Spacing.l - 2)

                levelSection
                    .padding(.bottom, Spacing.l - 1)

                focusSection(preferences)

                routineSection(preferences)
                    .padding(.top, Spacing.l - 1)

                reviewSection(preferences)
                    .padding(.top, Spacing.l - 1)

                if let saveError {
                    Text(verbatim: saveError)
                        .font(Typography.micro)
                        .foregroundStyle(Color.mutedInk)
                        .padding(.top, Spacing.s)
                }
            }
            .padding(.horizontal, Spacing.screenGutter)
            .padding(.top, Spacing.m)
            .padding(.bottom, Spacing.l)
        }
        .task {
            guard learner.profile?.tierSummary != nil else { return }
            await ranking.refreshTier()
        }
        .sheet(isPresented: $isEditingPublicProfile) {
            EditPublicProfileSheet()
        }
    }

    private func effortSection(_ summary: TierSummary) -> some View {
        ProfileTierCard(summary: summary, next: ranking.tier?.nextTier)
    }

    @ViewBuilder
    private var identity: some View {
        if let username = learner.profile?.username {
            HStack(spacing: Spacing.s) {
                AvatarView(key: learner.profile?.avatarKey ?? "", size: 64, cornerRadius: Radii.card)
                Text(verbatim: username)
                    .font(.system(.title2, weight: .heavy))
                    .tracking(-0.8)
                    .foregroundStyle(Color.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .accessibilityAddTraits(.isHeader)
                Spacer(minLength: Spacing.s)
                Button {
                    isEditingPublicProfile = true
                } label: {
                    Text("Edit")
                        .font(Typography.micro.weight(.heavy))
                        .foregroundStyle(Color.selectedInk)
                        .frame(minHeight: Spacing.minTouchTarget)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel(Text("Edit name and avatar"))
            }
        } else {
            placeholderIdentity
        }
    }

    private var placeholderIdentity: some View {
        let name = String(localized: "Learner", bundle: .appLanguage)
        return HStack(spacing: Spacing.s) {
            RoundedRectangle(cornerRadius: Radii.card, style: .continuous)
                .fill(Color.selectedSurface)
                .frame(width: 64, height: 64)
                .overlay(
                    Text(verbatim: String(name.prefix(1)))
                        .font(Typography.challengeTerm)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                        .foregroundStyle(Color.selectedInk)
                )
                .accessibilityHidden(true)
            Text(verbatim: name)
                .font(.system(.title2, weight: .heavy))
                .tracking(-0.8)
                .foregroundStyle(Color.ink)
                .accessibilityAddTraits(.isHeader)
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
                dataRow("arrow.clockwise", label: "Reviews / session", value: Text("\(preferences.effectiveReviewsPerSession) words"))
                Divider().overlay(Color.neutralSurface)
                dataRow("calendar", label: "Learning days", value: Text(verbatim: daysSummary(preferences)))
                Divider().overlay(Color.neutralSurface)
                dataRow("bell", label: "Reminder", value: preferences.reminderEnabled
                    ? Text(preferences.reminderDate, format: .dateTime.hour().minute())
                    : Text("Off"))
                Divider().overlay(Color.neutralSurface)
                toggleRow("scalemass", label: "Balance reviews and new words",
                          hint: "Fewer new words while many words wait for review",
                          isOn: learner.home?.reviewLoad?.autoBalance ?? learner.profile?.settings.autoBalanceNewWords ?? false) { enabled in
                    try await learner.setAutoBalance(enabled)
                }
                if let override = learner.home?.reviewLoad?.override {
                    Divider().overlay(Color.neutralSurface)
                    overrideRow(override)
                }
            }
            .padding(.horizontal, Spacing.m)
            .padding(.vertical, Spacing.xxs)
            .cardSurface(radius: Radii.card - 2)
        }
    }

    /// Collections the learner has learned from. The active one is always reviewed.
    private func reviewSection(_ preferences: LearningPreferences) -> some View {
        let collections = TopicCatalog.collections.filter { ($0.learned ?? 0) > 0 }
        return VStack(alignment: .leading, spacing: Spacing.s) {
            PlanSectionTitle(text: "Review")
            if collections.isEmpty {
                Text("Collections you learn from will show up here.")
                    .font(Typography.secondary)
                    .foregroundStyle(Color.mutedInk)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(collections.enumerated()), id: \.element.id) { index, collection in
                        if index > 0 { Divider().overlay(Color.neutralSurface) }
                        reviewRow(collection, isActive: collection.id == preferences.collectionID)
                    }
                }
                .padding(.horizontal, Spacing.m)
                .padding(.vertical, Spacing.xxs)
                .cardSurface(radius: Radii.card - 2)
            }
        }
    }

    private func reviewRow(_ collection: VocabCollection, isActive: Bool) -> some View {
        let isReviewed = isActive || !learner.isReviewPaused(collectionID: collection.id)
        return HStack(spacing: Spacing.s) {
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(verbatim: collection.name)
                    .font(Typography.secondary.weight(.semibold))
                    .foregroundStyle(Color.ink)
                Text(isActive
                     ? "\(collection.learned ?? 0) words · Your current collection is always reviewed"
                     : "\(collection.learned ?? 0) words learned")
                    .font(Typography.micro)
                    .foregroundStyle(Color.mutedInk)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: Spacing.s)
            Toggle("Review this collection’s words", isOn: Binding(
                get: { isReviewed },
                set: { reviewed in save { try await learner.setReviewPaused(!reviewed, collectionID: collection.id) } }
            ))
            .labelsHidden()
            .disabled(isActive)
        }
        .frame(minHeight: 54)
        .accessibilityElement(children: .combine)
    }

    private func toggleRow(_ systemImage: String, label: LocalizedStringKey, hint: LocalizedStringKey, isOn: Bool,
                           onChange: @escaping (Bool) async throws -> Void) -> some View {
        HStack(spacing: Spacing.s) {
            Image(systemName: systemImage)
                .foregroundStyle(Color.mutedInk)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(label)
                    .font(Typography.secondary.weight(.semibold))
                    .foregroundStyle(Color.ink)
                Text(hint)
                    .font(Typography.micro)
                    .foregroundStyle(Color.mutedInk)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: Spacing.s)
            Toggle(label, isOn: Binding(get: { isOn }, set: { value in save { try await onChange(value) } }))
                .labelsHidden()
        }
        .frame(minHeight: 54)
    }

    private func overrideRow(_ override: NewWordOverride) -> some View {
        HStack(spacing: Spacing.s) {
            Image(systemName: "arrow.down.circle")
                .foregroundStyle(Color.mutedInk)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text("Lowered to \(override.value) new words")
                    .font(Typography.secondary.weight(.semibold))
                    .foregroundStyle(Color.ink)
                Group {
                    if override.mode == .untilDate, let until = override.until {
                        Text("Until \(until.formatted(.dateTime.weekday(.wide).hour().minute().locale(AppLanguage.active.locale)))")
                    } else {
                        Text("Until 10 or fewer words are waiting")
                    }
                }
                .font(Typography.micro)
                .foregroundStyle(Color.mutedInk)
            }
            Spacer(minLength: Spacing.s)
            Button {
                save { try await learner.clearNewWordOverride() }
            } label: {
                Text("Cancel")
                    .font(Typography.micro.weight(.heavy))
                    .foregroundStyle(Color.selectedInk)
                    .frame(minHeight: Spacing.minTouchTarget)
            }
            .accessibilityLabel(Text("Cancel lowered new words"))
        }
        .frame(minHeight: 54)
    }

    private func save(_ change: @escaping () async throws -> Void) {
        Task {
            do {
                try await change()
                saveError = nil
            } catch {
                saveError = error.asAPIError.userMessage
            }
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
