import SwiftUI

struct PracticeLabView: View {
    @Environment(TemplateSandboxStore.self) private var sandbox
    @Environment(ChallengeRunStore.self) private var challengeRun
    @Environment(\.motion) private var motion

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.l) {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text("Practice Lab")
                        .font(Typography.display)
                        .tracking(-1)
                        .foregroundStyle(Color.ink)
                        .accessibilityAddTraits(.isHeader)
                    Text("Try any exercise template. Results here are practice only — they don’t change your session.")
                        .font(Typography.secondary)
                        .foregroundStyle(Color.mutedInk)
                        .fixedSize(horizontal: false, vertical: true)
                }

                VStack(spacing: Spacing.s) {
                    ForEach(sandbox.templates) { template in
                        TemplateCard(template: template) {
                            motion.perform(MotionTokens.transition) { sandbox.open(template.id) }
                        }
                    }
                }

                VStack(alignment: .leading, spacing: Spacing.s) {
                    Text("Challenge games")
                        .font(Typography.emphasis)
                        .foregroundStyle(Color.ink)
                        .accessibilityAddTraits(.isHeader)
                    // A static plan on the same engine as a live run: no API, no commit, no stars.
                    GameCard(title: "Match Madness", subtitle: "A 90-second round with example words.", systemImage: "timer") {
                        motion.perform(MotionTokens.transition) { challengeRun.startSandbox(plan: .sandbox(), timed: true) }
                    }
                    GameCard(title: "Match Madness, untimed", subtitle: "The same board with no clock, at your own pace.", systemImage: "tortoise") {
                        motion.perform(MotionTokens.transition) { challengeRun.startSandbox(plan: .sandbox(), timed: false) }
                    }
                }
            }
            .padding(.horizontal, Spacing.screenGutter)
            .padding(.top, Spacing.m)
            .padding(.bottom, Spacing.l)
        }
        .safeAreaInset(edge: .top) {
            HStack {
                BackButton(label: "Home") {
                    motion.perform(MotionTokens.transition) { sandbox.closeLab() }
                }
                Spacer()
            }
            .padding(.horizontal, Spacing.screenGutter)
            .background(Color.canvas)
        }
    }
}

private struct TemplateCard: View {
    let template: LabTemplate
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: Spacing.m) {
                RoundedRectangle(cornerRadius: Radii.chip, style: .continuous)
                    .fill(Color.neutralSurface)
                    .frame(width: 48, height: 48)
                    .overlay(
                        Image(systemName: template.systemImage)
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(Color.ink)
                    )
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    HStack(spacing: Spacing.xs) {
                        Text(verbatim: template.title)
                            .font(Typography.emphasis)
                            .foregroundStyle(Color.ink)
                        Spacer(minLength: 0)
                    }
                    Text(verbatim: template.action)
                        .font(Typography.secondary)
                        .foregroundStyle(Color.mutedInk)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                    if template.tasks.count > 1 {
                        Text("\(template.tasks.count) examples")
                            .font(Typography.micro.weight(.semibold))
                            .foregroundStyle(Color.selectedInk)
                    }
                }
            }
            .padding(Spacing.m)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(ActionButtonStyle(kind: .secondary))
        .accessibilityElement(children: .combine)
        .accessibilityHint(Text("Opens the exercise."))
    }
}

private struct GameCard: View {
    let title: LocalizedStringKey
    let subtitle: LocalizedStringKey
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: Spacing.m) {
                RoundedRectangle(cornerRadius: Radii.chip, style: .continuous)
                    .fill(Color.selectedSurface)
                    .frame(width: 48, height: 48)
                    .overlay(
                        Image(systemName: systemImage)
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(Color.selectedInk)
                    )
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text(title)
                        .font(Typography.emphasis)
                        .foregroundStyle(Color.ink)
                    Text(subtitle)
                        .font(Typography.secondary)
                        .foregroundStyle(Color.mutedInk)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            .padding(Spacing.m)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(ActionButtonStyle(kind: .secondary))
        .accessibilityElement(children: .combine)
        .accessibilityHint(Text("Starts a practice round."))
    }
}

struct BackButton: View {
    let label: LocalizedStringKey
    let action: () -> Void

    var body: some View {
        Button(action: action) { BackButtonLabel() }
            .buttonStyle(PressScaleButtonStyle())
            .accessibilityLabel(Text(label))
    }
}
