import SwiftUI

/// Welcome → Topics → Routine → Ready. One step is mounted at a time and slides in like the session flow.
struct OnboardingView: View {
    @Environment(OnboardingStore.self) private var store
    @Environment(\.motion) private var motion

    var body: some View {
        ZStack {
            Color.canvas.ignoresSafeArea()
            screen
                .id(store.step)
                .transition(motion.stepTransition)
        }
    }

    @ViewBuilder
    private var screen: some View {
        switch store.step {
        case .welcome: WelcomeScreen()
        case .topics: TopicsScreen()
        case .routine: RoutineScreen()
        case .ready: ReadyScreen()
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
        .scrollBounceBehavior(.basedOnSize)
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
                .fill(Color.reward)
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

// MARK: - Topics

private struct TopicsScreen: View {
    @Environment(OnboardingStore.self) private var store
    @Environment(\.motion) private var motion

    var body: some View {
        @Bindable var store = store

        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                StepHeader(step: 1, backLabel: "Back to welcome") {
                    motion.perform(MotionTokens.transition) { store.back() }
                }

                PunctuatedTitle(text: "Your interests")
                    .padding(.top, Spacing.l + 6)
                    .padding(.bottom, Spacing.l)

                TopicPicker(browser: $store.topics, selectedIDs: store.draft.topicIDs) { id in
                    store.toggleTopic(id)
                }
            }
            .padding(.horizontal, Spacing.screenGutter)
            .padding(.top, Spacing.xs)
            .padding(.bottom, Spacing.l)
        }
        .scrollDismissesKeyboard(.interactively)
        .safeAreaInset(edge: .bottom) {
            PinnedActionBar {
                VStack(spacing: Spacing.s) {
                    if store.canContinueFromTopics {
                        Text("\(store.draft.topicIDs.count) topics selected")
                            .font(Typography.micro.weight(.semibold))
                            .foregroundStyle(Color.mutedInk)
                            .contentTransition(.numericText())
                    }
                    PrimaryButton(
                        title: "Continue",
                        requirement: "Choose at least one topic",
                        isEnabled: store.canContinueFromTopics
                    ) {
                        motion.perform(MotionTokens.transition) { store.continueToRoutine() }
                    }
                }
            }
        }
    }
}

// MARK: - Routine

private struct RoutineScreen: View {
    @Environment(OnboardingStore.self) private var store
    @Environment(\.motion) private var motion

    var body: some View {
        @Bindable var store = store

        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                StepHeader(step: 2, backLabel: "Back to topics") {
                    motion.perform(MotionTokens.transition) { store.back() }
                }

                PunctuatedTitle(text: "Your routine")
                    .padding(.top, Spacing.l + 6)
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
            }
            .padding(.horizontal, Spacing.screenGutter)
            .padding(.top, Spacing.xs)
            .padding(.bottom, Spacing.l)
        }
        .safeAreaInset(edge: .bottom) {
            PinnedActionBar {
                PrimaryButton(
                    title: "Create my flow",
                    requirement: "Choose at least one learning day",
                    isEnabled: store.draft.isComplete
                ) {
                    motion.perform(MotionTokens.transition) { store.createFlow() }
                }
            }
        }
    }
}

// MARK: - Ready

private struct ReadyScreen: View {
    @Environment(OnboardingStore.self) private var store
    @Environment(\.motion) private var motion
    @State private var hasAppeared = false

    var body: some View {
        VStack(spacing: 0) {
            StepHeader(backLabel: "Back to routine") {
                motion.perform(MotionTokens.transition) { store.back() }
            }
            .padding(.horizontal, Spacing.screenGutter)
            .padding(.top, Spacing.xs)

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
                        summaryTag(Text("\(store.draft.topicIDs.count) topics"), highlighted: true)
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
            .scrollBounceBehavior(.basedOnSize)
        }
        .safeAreaInset(edge: .bottom) {
            PinnedActionBar {
                PrimaryButton(title: "Start learning") {
                    motion.perform(MotionTokens.transition) { store.finish() }
                }
            }
        }
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
                    .fill(Color.reward)
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
        return Text("Reminder \(store.draft.reminderDate.formatted(date: .omitted, time: .shortened))")
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
}
