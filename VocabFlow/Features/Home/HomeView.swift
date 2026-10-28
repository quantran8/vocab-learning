import SwiftUI

struct HomeView: View {
    let onShowWords: () -> Void
    @Environment(SessionStore.self) private var session
    @Environment(ProgressStore.self) private var progress
    @Environment(LearningPlanStore.self) private var plan
    @Environment(\.motion) private var motion
    @State private var today = Date()

    var body: some View {
        let status = progress.status(for: plan.current, on: today)

        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text(today.formatted(.dateTime.weekday(.wide).month(.abbreviated).day()))
                    .font(Typography.eyebrow)
                    .tracking(Typography.eyebrowTracking)
                    .textCase(.uppercase)
                    .foregroundStyle(Color.mutedInk)

                PunctuatedTitle(text: heading(status))
                    .padding(.top, Spacing.xs + 1)

                TodayHero(status: status)
                    .padding(.top, Spacing.m + 3)

                primaryAction(status)
                    .padding(.top, Spacing.s + 2)

                upNext(status)
                    .padding(.top, Spacing.l - 1)
            }
            .padding(.horizontal, Spacing.screenGutter)
            .padding(.top, Spacing.m)
            .padding(.bottom, Spacing.l)
        }
        .onAppear { today = progress.today }
    }

    private func heading(_ status: TodayStatus) -> LocalizedStringKey {
        switch status.mode {
        case .rest: "Take it easy"
        case .reviewFocus: "Time to revisit"
        case .completed: "Nice flow"
        case .learning: status.introduced > 0 ? "Keep it going" : "Your daily flow"
        }
    }

    // MARK: Actions

    @ViewBuilder
    private func primaryAction(_ status: TodayStatus) -> some View {
        switch status.mode {
        case .rest:
            EmptyView()
        case .reviewFocus:
            PrimaryButton(title: "Start review") { start(.review) }
        case .completed:
            if status.due > 0 {
                PrimaryButton(title: "Review words") { start(.review) }
            } else {
                PrimaryButton(title: "My Words", action: onShowWords)
            }
        case .learning:
            PrimaryButton(title: status.introduced > 0 ? "Continue flow" : "Start today’s flow") { start(.learn) }
        }
    }

    private func start(_ kind: ProgressStore.RunKind) {
        progress.beginRun(kind)
        motion.perform(MotionTokens.transition) { session.start() }
    }

    // MARK: Up next

    private func upNext(_ status: TodayStatus) -> some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            PlanSectionTitle(text: status.mode == .reviewFocus ? "Also for today" : "Up next")
            if status.mode == .reviewFocus {
                TaskRow(
                    systemImage: "book",
                    title: Text("\(status.remaining) new words ready"),
                    subtitle: Text("Your daily new words"),
                    action: { start(.learn) }
                )
            } else if status.due > 0 {
                TaskRow(
                    systemImage: "arrow.triangle.2.circlepath",
                    title: Text("Review words"),
                    subtitle: Text("\(status.due) due today"),
                    count: status.due,
                    action: { start(.review) }
                )
            } else {
                TaskRow(
                    systemImage: "checkmark.circle",
                    title: Text("All caught up"),
                    subtitle: Text("No reviews due"),
                    action: nil
                )
            }
        }
    }
}

// MARK: - Hero

/// Black status card. Its content changes with the day's mode; decorative parts are hidden from VoiceOver.
private struct TodayHero: View {
    let status: TodayStatus
    @Environment(\.motion) private var motion

    private let secondaryInk = Color.white.opacity(0.74)

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(eyebrow)
                    .font(Typography.eyebrow)
                    .tracking(Typography.eyebrowTracking)
                    .foregroundStyle(secondaryInk)
                Spacer()
                RoundedRectangle(cornerRadius: Radii.chip, style: .continuous)
                    .fill(Color.reward)
                    .frame(width: 30, height: 30)
                    .overlay(
                        Image(systemName: badgeIcon)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(Color.ink)
                    )
                    .rotationEffect(.degrees(12))
                    .accessibilityHidden(true)
            }
            Spacer(minLength: Spacing.l)
            content
        }
        .padding(Spacing.l - 2)
        .frame(maxWidth: .infinity, minHeight: 214, alignment: .leading)
        .background(alignment: .topTrailing) { rings }
        .background(Color.ink)
        .clipShape(RoundedRectangle(cornerRadius: Radii.hero, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    private var rings: some View {
        ZStack {
            Circle().strokeBorder(Color.white.opacity(0.17), lineWidth: 1).frame(width: 184, height: 184)
                .offset(x: 59, y: -45)
            Circle().strokeBorder(Color.white.opacity(0.09), lineWidth: 1).frame(width: 133, height: 133)
                .offset(x: 35, y: -20)
        }
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private var content: some View {
        switch status.mode {
        case .rest:
            VStack(alignment: .leading, spacing: 0) {
                RoundedRectangle(cornerRadius: Radii.hero, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.27), lineWidth: 2)
                    .frame(width: 72, height: 72)
                    .overlay(
                        Image(systemName: "moon")
                            .font(.system(size: 34, weight: .semibold))
                            .foregroundStyle(Color.reward)
                    )
                    .rotationEffect(.degrees(-12))
                    .accessibilityHidden(true)
                    .padding(.bottom, Spacing.m)
                Text("No new words today.")
                    .font(.system(size: 27, weight: .heavy))
                    .tracking(-1.3)
                    .foregroundStyle(.white)
                Text("Your next learning day is coming up.")
                    .font(Typography.micro.weight(.semibold))
                    .foregroundStyle(secondaryInk)
                    .padding(.top, Spacing.s - 1)
            }
        case .completed:
            VStack(alignment: .leading, spacing: 0) {
                Label {
                    Text("All done.")
                } icon: {
                    Image(systemName: "checkmark.circle")
                        .foregroundStyle(Color.success)
                }
                .font(.system(size: 29, weight: .heavy))
                .tracking(-1.5)
                .foregroundStyle(.white)
                Text(verbatim: "\(status.goal) / \(status.goal)")
                    .font(.system(size: 35, weight: .heavy).monospacedDigit())
                    .tracking(-2)
                    .foregroundStyle(.white)
                    .padding(.top, Spacing.s + 1)
                Text("New words introduced today")
                    .font(Typography.micro.weight(.semibold))
                    .foregroundStyle(secondaryInk)
                    .padding(.top, Spacing.s - 1)
            }
        case .reviewFocus:
            VStack(alignment: .leading, spacing: 0) {
                bigNumber(status.due, unit: "words")
                Text("Ready to revisit")
                    .font(Typography.micro.weight(.semibold))
                    .foregroundStyle(secondaryInk)
                    .padding(.top, Spacing.s - 1)
            }
        case .learning:
            VStack(alignment: .leading, spacing: 0) {
                bigNumber(status.remaining, unit: "new words")
                Text("\(status.introduced) / \(status.goal) introduced")
                    .font(Typography.micro.weight(.semibold))
                    .foregroundStyle(secondaryInk)
                    .padding(.top, Spacing.s - 1)
                progressBar
                    .padding(.top, Spacing.m + 1)
            }
            .overlay(alignment: .topTrailing) { miniTiles.offset(y: -6) }
        }
    }

    private func bigNumber(_ value: Int, unit: LocalizedStringKey) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: Spacing.xs) {
            Text(verbatim: "\(value)")
                .font(.system(size: 71, weight: .heavy).monospacedDigit())
                .tracking(-5)
                .contentTransition(.numericText(value: Double(value)))
            Text(unit)
                .font(.system(size: 18, weight: .bold))
                .tracking(-0.6)
        }
        .foregroundStyle(.white)
        .lineLimit(1)
        .minimumScaleFactor(0.7)
    }

    private var progressBar: some View {
        Capsule()
            .fill(Color.white.opacity(0.2))
            .frame(height: 6)
            .overlay(alignment: .leading) {
                GeometryReader { proxy in
                    Capsule()
                        .fill(Color.interactive)
                        .frame(width: proxy.size.width * min(1, status.fraction))
                }
            }
            .clipShape(Capsule())
            .animation(motion.animation(MotionTokens.progress), value: status.fraction)
            .accessibilityHidden(true)
    }

    private var miniTiles: some View {
        HStack(spacing: Spacing.xxs) {
            ForEach(Array(["F", "L", "O", "W"].enumerated()), id: \.offset) { index, letter in
                let isAccent = index == 1
                let shape = RoundedRectangle(cornerRadius: 7, style: .continuous)
                Text(verbatim: letter)
                    .font(.system(size: 15, weight: .heavy))
                    .foregroundStyle(isAccent ? Color.ink : Color.selectedInk)
                    .frame(width: 28, height: 31)
                    .background(isAccent ? Color.reward : Color.selectedSurface, in: shape)
                    .background(shape.fill(isAccent ? Color.rewardDepth : Color.interactiveDepth).offset(y: 3))
            }
        }
        .rotationEffect(.degrees(-9))
        .accessibilityHidden(true)
    }

    private var eyebrow: LocalizedStringKey {
        switch status.mode {
        case .rest: "REST DAY"
        case .reviewFocus: "REVIEW QUEUE"
        case .completed: "GOAL REACHED"
        case .learning: "TODAY’S FLOW"
        }
    }

    private var badgeIcon: String {
        switch status.mode {
        case .rest: "moon.fill"
        case .reviewFocus: "arrow.triangle.2.circlepath"
        case .completed: "checkmark"
        case .learning: "sparkle"
        }
    }
}

// MARK: - Task row

/// Bordered list row with a tinted leading icon. With no action it renders as a muted, finished state.
struct TaskRow: View {
    let systemImage: String
    let title: Text
    let subtitle: Text
    var count: Int?
    let action: (() -> Void)?

    var body: some View {
        if let action {
            Button(action: action) { label }
                .buttonStyle(ChunkyButtonStyle(kind: .secondary))
        } else {
            label
                .background(Color.quietSurface, in: RoundedRectangle(cornerRadius: Radii.primaryAction, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: Radii.primaryAction, style: .continuous)
                        .strokeBorder(Color.stroke, lineWidth: 1.5)
                )
                .accessibilityElement(children: .combine)
        }
    }

    private var label: some View {
        let isDone = action == nil
        return HStack(spacing: Spacing.s + 1) {
            RoundedRectangle(cornerRadius: Radii.tile, style: .continuous)
                .fill(isDone ? Color.successSurface : Color.selectedSurface)
                .frame(width: 45, height: 45)
                .overlay(
                    Image(systemName: systemImage)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(isDone ? Color.successInk : Color.selectedInk)
                )
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                title
                    .font(Typography.emphasis)
                    .foregroundStyle(Color.ink)
                subtitle
                    .font(Typography.micro)
                    .foregroundStyle(Color.mutedInk)
            }
            Spacer(minLength: 0)
            if let count {
                Text(verbatim: "\(count)")
                    .font(Typography.micro.weight(.heavy).monospacedDigit())
                    .foregroundStyle(Color.selectedInk)
                    .padding(.horizontal, Spacing.xs + 1)
                    .padding(.vertical, Spacing.xxs + 2)
                    .background(Color.selectedSurface, in: RoundedRectangle(cornerRadius: Radii.chip - 1, style: .continuous))
                    .accessibilityHidden(true)
            }
            if !isDone {
                Image(systemName: "chevron.right")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Color.mutedInk)
                    .accessibilityHidden(true)
            }
        }
        .padding(Spacing.m - 2)
        .frame(minHeight: 79)
        .opacity(isDone ? 0.85 : 1)
    }
}
