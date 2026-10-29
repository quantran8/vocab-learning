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
                Text(verbatim: "vocab flow")
                    .font(Typography.wordmark)
                    .tracking(-0.6)
                    .foregroundStyle(Color.ink)
                    .accessibilityLabel(Text(verbatim: "Vocab Flow"))

                Text("DAILY SESSION")
                    .font(Typography.eyebrow)
                    .tracking(Typography.eyebrowTracking)
                    .foregroundStyle(Color.mutedInk)
                    .padding(.top, Spacing.xl)

                Text(heading(status))
                    .font(Typography.display)
                    .tracking(-1.2)
                    .foregroundStyle(Color.ink)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
                    .padding(.top, Spacing.xs)

                sessionCard(status)
                    .padding(.top, Spacing.m + 2)

                Rectangle()
                    .fill(Color.stroke)
                    .frame(height: 1)
                    .padding(.vertical, Spacing.l + 4)
                    .accessibilityHidden(true)

                Text("Weekly Challenge")
                    .font(Typography.screenTitle)
                    .tracking(Typography.tightTracking)
                    .foregroundStyle(Color.ink)
                    .accessibilityAddTraits(.isHeader)

                WeeklyChallengeCard(weekly: progress.weekly(on: today))
                    .padding(.top, Spacing.m)
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
        case .learning: status.introduced > 0 ? "Keep it going" : "Ready to learn?"
        }
    }

    private func sessionCard(_ status: TodayStatus) -> some View {
        VStack(alignment: .leading, spacing: Spacing.l) {
            HStack(spacing: Spacing.xs) {
                StatChip(value: status.due, label: "to review")
                StatChip(value: status.remaining, label: "new words")
            }
            primaryAction(status)
        }
        .padding(Spacing.l - 4)
        .cardSurface()
        .shadow(color: Color.ink.opacity(0.06), radius: 6, y: 4)
    }

    // MARK: Actions

    @ViewBuilder
    private func primaryAction(_ status: TodayStatus) -> some View {
        switch status.mode {
        case .rest:
            if status.due > 0 {
                PrimaryButton(title: "Review words") { start(.review) }
            }
        case .reviewFocus:
            PrimaryButton(title: "Start review") { start(.review) }
        case .completed:
            if status.due > 0 {
                PrimaryButton(title: "Review words") { start(.review) }
            } else {
                PrimaryButton(title: "My Words", action: onShowWords)
            }
        case .learning:
            PrimaryButton(title: status.introduced > 0 ? "Continue flow" : "Start Flow") { start(.learn) }
        }
    }

    private func start(_ kind: ProgressStore.RunKind) {
        progress.beginRun(kind)
        motion.perform(MotionTokens.transition) { session.start() }
    }
}

// MARK: - Stat chip

private struct StatChip: View {
    let value: Int
    let label: LocalizedStringKey

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Spacing.xs) {
            Text(verbatim: "\(value)")
                .font(Typography.screenTitle.monospacedDigit())
                .contentTransition(.numericText(value: Double(value)))
            Text(label)
                .font(Typography.micro.weight(.semibold))
        }
        .foregroundStyle(Color.ink)
        .padding(.horizontal, Spacing.s)
        .padding(.vertical, Spacing.xs + 2)
        .background(Color.neutralSurface, in: RoundedRectangle(cornerRadius: Radii.chip, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Weekly challenge

private struct WeeklyChallengeCard: View {
    let weekly: WeeklyProgress
    @Environment(\.motion) private var motion

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            HStack {
                Text("This week’s words")
                    .font(Typography.emphasis)
                    .foregroundStyle(Color.ink)
                Spacer()
                Text("Day \(weekly.day) / \(WeeklyProgress.length)")
                    .font(Typography.micro.weight(.bold).monospacedDigit())
                    .foregroundStyle(Color.ink)
                    .padding(.horizontal, Spacing.xs + 1)
                    .padding(.vertical, Spacing.xxs + 2)
                    .background(Color.neutralSurface, in: RoundedRectangle(cornerRadius: Radii.chip - 2, style: .continuous))
            }

            progressBar

            HStack {
                Text("^[\(weekly.wordsLearned) word](inflect: true) this week")
                Spacer()
                opensText
            }
            .font(Typography.micro)
            .foregroundStyle(Color.mutedInk)
        }
        .padding(Spacing.m + 2)
        .cardSurface()
        .accessibilityElement(children: .combine)
    }

    private var opensText: Text {
        weekly.daysUntilOpen > 0
            ? Text("Opens in ^[\(weekly.daysUntilOpen) day](inflect: true)")
            : Text("Opens today")
    }

    private var progressBar: some View {
        Capsule()
            .fill(Color.track)
            .frame(height: 8)
            .overlay(alignment: .leading) {
                GeometryReader { proxy in
                    Capsule()
                        .fill(Color.interactive)
                        .frame(width: proxy.size.width * min(1, weekly.fraction))
                }
            }
            .clipShape(Capsule())
            .animation(motion.animation(MotionTokens.progress), value: weekly.fraction)
            .accessibilityHidden(true)
    }
}
