import SwiftUI

/// Welcome → Level (optionally through the placement test) → Collection → Topics → Routine → Ready.
/// Welcome and the test are whole screens; every other step shares `SetupFlowView`'s frame.
struct OnboardingView: View {
    private enum Screen {
        case welcome, setup, placement
    }

    @Environment(OnboardingStore.self) private var store
    @Environment(\.motion) private var motion

    private var current: Screen {
        switch store.step {
        case .welcome: .welcome
        case .placement: .placement
        default: .setup
        }
    }

    var body: some View {
        ZStack {
            Color.canvas.ignoresSafeArea()
            screen
                .id(current)
                .transition(motion.stepTransition(isMovingBack: { store.isMovingBack }))
        }
        // Here rather than at each call site: some steps only change once a request answers.
        .animation(motion.animation(MotionTokens.stepSlide), value: store.step)
    }

    @ViewBuilder
    private var screen: some View {
        switch current {
        case .welcome: WelcomeScreen()
        case .setup: SetupFlowView()
        case .placement: PlacementScreen()
        }
    }
}

// MARK: - Welcome

private struct WelcomeScreen: View {
    @Environment(OnboardingStore.self) private var store
    @Environment(\.motion) private var motion

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                BrandBar()

                PunctuatedTitle(text: "Make words\nstick", font: .system(size: 46, weight: .heavy))
                    .padding(.top, Spacing.xl * 2)

                Text("A little, every day.")
                    .font(Typography.body.weight(.medium))
                    .foregroundStyle(Color.mutedInk)
                    .padding(.top, Spacing.s)

                FlowHero()
                    .padding(.top, Spacing.l)
            }
            .padding(.horizontal, Spacing.screenGutter)
            .padding(.top, Spacing.s)
            .padding(.bottom, Spacing.l)
        }
        .safeAreaInset(edge: .bottom) {
            PinnedActionBar {
                PrimaryButton(title: "Get started") {
                    motion.perform(MotionTokens.transition) { store.begin() }
                }
            }
        }
    }
}

/// F·L·O·W tiles dropping onto a soft disc. Decorative only.
private struct FlowHero: View {
    @Environment(\.motion) private var motion
    @State private var hasAppeared = false

    private let letters = ["F", "L", "O", "W"]

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.neutralSurface)
                .frame(width: 235, height: 235)
                .overlay(Circle().strokeBorder(Color.stroke, lineWidth: 1).padding(14))
            RoundedRectangle(cornerRadius: Radii.tile, style: .continuous)
                .fill(Color.selectedSurface)
                .frame(width: 53, height: 53)
                .rotationEffect(.degrees(21))
                .offset(x: 128, y: -62)
            Capsule()
                .fill(Color.interactive)
                .frame(width: 42, height: 10)
                .rotationEffect(.degrees(-30))
                .offset(x: -124, y: 66)

            HStack(spacing: Spacing.xxs + 1) {
                ForEach(Array(letters.enumerated()), id: \.offset) { index, letter in
                    heroTile(letter, isAccent: index == 2)
                        .opacity(hasAppeared ? 1 : 0)
                        .offset(y: hasAppeared ? 0 : 27)
                        .rotationEffect(.degrees(hasAppeared ? 0 : -5))
                        .animation(
                            motion.travel(MotionTokens.entrance.delay(Double(index) * 0.09)),
                            value: hasAppeared
                        )
                }
            }
            .rotationEffect(.degrees(-4))
        }
        .frame(maxWidth: .infinity)
        .frame(height: 280)
        .accessibilityHidden(true)
        .onAppear { hasAppeared = true }
    }

    private func heroTile(_ letter: String, isAccent: Bool) -> some View {
        let shape = RoundedRectangle(cornerRadius: Radii.tile + 1, style: .continuous)
        let edge = isAccent ? Color.interactiveDepth : Color.ink
        return Text(verbatim: letter)
            .font(.system(size: 42, weight: .heavy))
            .foregroundStyle(isAccent ? Color.white : Color.ink)
            .frame(width: 66, height: 78)
            .background(isAccent ? Color.interactive : Color.surface, in: shape)
            .overlay(shape.strokeBorder(edge, lineWidth: 2))
            .background(shape.fill(edge).offset(y: 5))
    }
}

// MARK: - Setup flow

/// Steps counted by the header indicator: Level, Collection, Topics, Routine.
private let setupStepCount = 4

/// Question-style step titles run longer than the one-word ones, so they sit a size down.
private let questionFont = Font.system(.title, weight: .heavy)

/// One persistent frame for Level → Ready. The header and pinned action stay mounted;
/// only the step's content slides, forward on next and backward on back.
private struct SetupFlowView: View {
    @Environment(OnboardingStore.self) private var store
    @Environment(\.motion) private var motion

    var body: some View {
        VStack(spacing: 0) {
            StepHeader(step: stepNumber, totalSteps: setupStepCount, backLabel: backLabel) {
                store.back()
            }
            .padding(.horizontal, Spacing.screenGutter)
            .padding(.top, Spacing.xs)

            ZStack(alignment: .top) {
                content
                    .id(store.step)
                    .transition(motion.stepTransition(isMovingBack: { store.isMovingBack }))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .clipped()

            PinnedActionBar {
                VStack(spacing: Spacing.s) {
                    if store.step == .topics, store.canContinueFromTopics {
                        Text("\(store.draft.topicIDs.count) topics selected")
                            .font(Typography.micro.weight(.semibold))
                            .foregroundStyle(Color.mutedInk)
                            .contentTransition(.numericText())
                    }
                    PrimaryButton(title: actionTitle, requirement: requirement, isEnabled: canAct, action: act)
                }
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch store.step {
        case .level: LevelStep()
        case .collection: CollectionStep()
        case .topics: TopicsStep()
        case .routine: RoutineStep()
        default: ReadyStep()
        }
    }

    private var stepNumber: Int {
        switch store.step {
        case .collection: 2
        case .topics: 3
        case .routine, .ready: 4
        default: 1
        }
    }

    private var backLabel: LocalizedStringKey {
        switch store.step {
        case .collection: "Back to level"
        case .topics: "Back to collections"
        case .routine: "Back to topics"
        case .ready: "Back to routine"
        default: "Back to welcome"
        }
    }

    private var actionTitle: LocalizedStringKey {
        switch store.step {
        case .routine: "Create my flow"
        case .ready: "Start learning"
        default: "Continue"
        }
    }

    private var requirement: LocalizedStringKey? {
        switch store.step {
        case .collection: "Choose a collection"
        case .topics: "Choose at least one topic"
        case .routine: "Choose at least one learning day"
        default: nil
        }
    }

    private var canAct: Bool {
        switch store.step {
        case .level: store.level != nil && !store.isSaving
        case .collection: store.canContinueFromCollection
        case .topics: store.canContinueFromTopics
        case .routine: store.draft.isComplete && !store.isSaving
        default: true
        }
    }

    private func act() {
        switch store.step {
        case .level: Task { await store.continueToCollection() }
        case .collection: store.continueToTopics()
        case .topics: store.continueToRoutine()
        case .routine: Task { await store.createFlow() }
        default: store.finish()
        }
    }
}

/// A scrolling step body with the frame's margins.
private struct StepPage<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                content
            }
            .padding(.horizontal, Spacing.screenGutter)
            .padding(.top, Spacing.l + 6)
            .padding(.bottom, Spacing.l)
        }
    }
}

// MARK: - Level

private struct LevelStep: View {
    @Environment(OnboardingStore.self) private var store
    @Environment(PlacementTestStore.self) private var placement
    @Environment(\.motion) private var motion

    var body: some View {
        StepPage {
            PunctuatedTitle(text: "What’s your English level", mark: "?")
                .padding(.bottom, Spacing.l)

            LazyVGrid(columns: [GridItem(.flexible(), spacing: Spacing.s), GridItem(.flexible())], spacing: Spacing.s) {
                ForEach(CEFRLevel.allCases) { level in
                    LevelTile(level: level, isSelected: store.level == level) {
                        motion.perform(MotionTokens.snap) { store.selectLevel(level) }
                    }
                }
            }

            placementButton
                .padding(.top, Spacing.m)

            SaveErrorText(message: store.errorMessage)
        }
    }

    private var placementButton: some View {
        let shape = RoundedRectangle(cornerRadius: Radii.card - 2, style: .continuous)
        return Button {
            placement.start()
            store.openPlacementTest()
        } label: {
            HStack(spacing: Spacing.s) {
                Image(systemName: "list.bullet")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Color.interactive)
                    .frame(width: 38, height: 38)
                    .overlay(
                        RoundedRectangle(cornerRadius: Radii.chip, style: .continuous)
                            .strokeBorder(Color.stroke, lineWidth: 1)
                    )
                    .accessibilityHidden(true)
                Text("Not sure? Take a short test")
                    .font(Typography.secondary.weight(.semibold))
                    .foregroundStyle(Color.ink)
                    .multilineTextAlignment(.leading)
            }
            .frame(maxWidth: .infinity, minHeight: 74)
            .padding(.horizontal, Spacing.s)
            .background(Color.surface, in: shape)
            .overlay(shape.strokeBorder(Color.stroke, lineWidth: 1.5))
            .contentShape(shape)
        }
        .buttonStyle(PressScaleButtonStyle())
    }
}

private struct PlacementScreen: View {
    @Environment(OnboardingStore.self) private var store

    var body: some View {
        PlacementTestView(
            doneTitle: "Continue",
            isDoneEnabled: !store.isSaving,
            doneError: store.errorMessage,
            onDone: { result in
                Task { await store.acceptPlacement(result) }
            },
            onChooseLevel: { result in
                store.chooseLevelByHand(after: result)
            },
            onLeave: {
                store.back()
            }
        )
    }
}

private struct SaveErrorText: View {
    let message: String?

    var body: some View {
        if let message {
            Text(verbatim: message)
                .font(Typography.secondary)
                .foregroundStyle(Color.errorInk)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, Spacing.m)
        }
    }
}

// MARK: - Collection

private struct CollectionStep: View {
    @Environment(OnboardingStore.self) private var store
    @Environment(\.motion) private var motion

    var body: some View {
        StepPage {
            PunctuatedTitle(text: "What kind of vocabulary would you like to learn", mark: "?", font: questionFont)
                .padding(.bottom, Spacing.l)

            CollectionPicker(selectedID: store.draft.collectionID) { id in
                motion.perform(MotionTokens.snap) { store.selectCollection(id) }
            }
        }
    }
}

// MARK: - Topics

private struct TopicsStep: View {
    @Environment(OnboardingStore.self) private var store

    var body: some View {
        StepPage {
            PunctuatedTitle(text: "What topics are you interested in", mark: "?", font: questionFont)
                .padding(.bottom, Spacing.l)

            if let collection = store.draft.collection {
                TopicPicker(
                    collection: collection,
                    selectedIDs: store.draft.topicIDs,
                    onToggleTopic: { store.toggleTopic($0) },
                    onToggleAll: { store.toggleAllTopics() }
                )
            }
        }
    }
}

// MARK: - Routine

private struct RoutineStep: View {
    @Environment(OnboardingStore.self) private var store

    var body: some View {
        @Bindable var store = store

        StepPage {
            PunctuatedTitle(text: "Your routine")
                .padding(.bottom, Spacing.xl + 2)

            VStack(alignment: .leading, spacing: Spacing.xl - 1) {
                VStack(alignment: .leading, spacing: Spacing.s) {
                    PlanSectionTitle(text: "New words / day")
                    WordsPerDayStepper(value: store.draft.wordsPerDay) { store.adjustWordsPerDay(by: $0) }
                }
                LearningDaysPicker(
                    selected: store.draft.learningDays,
                    onToggleDay: { store.toggleDay($0) },
                    onToggleEveryDay: { store.toggleEveryDay() }
                )
                ReminderPicker(preferences: $store.draft)
            }

            SaveErrorText(message: store.errorMessage)
        }
    }
}

// MARK: - Ready

private struct ReadyStep: View {
    @Environment(OnboardingStore.self) private var store
    @Environment(\.motion) private var motion
    @State private var hasAppeared = false

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                mark
                    .scaleEffect(hasAppeared ? 1 : 0.6)
                    .opacity(hasAppeared ? 1 : 0)
                    .padding(.bottom, Spacing.xl - 2)

                PunctuatedTitle(text: "You’re all set")
                    .multilineTextAlignment(.center)

                Text("Your flow is ready.")
                    .font(Typography.secondary.weight(.semibold))
                    .foregroundStyle(Color.mutedInk)
                    .padding(.top, Spacing.s - 2)
                    .padding(.bottom, Spacing.l - 2)

                FlowLayout(spacing: Spacing.xs - 1, lineSpacing: Spacing.xs - 1) {
                    if let collection = store.draft.collection {
                        summaryTag(Text(verbatim: collection.name), highlighted: true)
                    }
                    summaryTag(Text("\(store.draft.topicIDs.count) topics"))
                    summaryTag(Text("\(store.draft.wordsPerDay) words/day"))
                    summaryTag(Text("\(store.draft.learningDays.count) days/week"))
                    summaryTag(reminderText)
                }
                .frame(maxWidth: 300)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, Spacing.screenGutter)
            .padding(.vertical, Spacing.xl)
        }
        .defaultScrollAnchor(.center)
        .onAppear {
            withAnimation(motion.travel(MotionTokens.entrance.delay(0.1))) { hasAppeared = true }
        }
    }

    private var mark: some View {
        RoundedRectangle(cornerRadius: 28, style: .continuous)
            .fill(Color.selectedSurface)
            .frame(width: 98, height: 98)
            .overlay(alignment: .topTrailing) {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(Color.interactive)
                    .frame(width: 24, height: 24)
                    .rotationEffect(.degrees(28))
                    .offset(x: 11, y: -11)
            }
            .overlay(
                Image(systemName: "sparkles")
                    .font(.system(size: 40, weight: .semibold))
                    .foregroundStyle(Color.interactive)
                    .rotationEffect(.degrees(9))
            )
            .rotationEffect(.degrees(-9))
            .accessibilityHidden(true)
    }

    private var reminderText: Text {
        guard store.draft.reminderEnabled else { return Text("Reminders off") }
        return Text("Reminder \(store.draft.reminderDate.formatted(Date.FormatStyle(date: .omitted, time: .shortened, locale: AppLanguage.active.locale)))")
    }

    private func summaryTag(_ text: Text, highlighted: Bool = false) -> some View {
        text
            .font(Typography.micro.weight(.bold))
            .foregroundStyle(highlighted ? Color.selectedInk : Color.ink)
            .padding(.horizontal, Spacing.s)
            .padding(.vertical, Spacing.xs)
            .background(highlighted ? Color.selectedSurface : Color.surface, in: Capsule())
            .overlay(Capsule().strokeBorder(highlighted ? Color.interactive : Color.stroke, lineWidth: 1))
    }
}

#Preview {
    OnboardingView()
        .environment(OnboardingStore(
            plan: LearningPlanStore(storage: InMemoryPreferencesStore(), reminders: NoReminders()),
            haptics: NoOpFeedback()
        ))
        .environment(PlacementTestStore(api: OfflineVocabAPI(), haptics: NoOpFeedback()))
}
