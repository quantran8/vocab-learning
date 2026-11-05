import SwiftUI

/// Pushed from My Words' Random Practice tile. Nothing is planned until Start.
struct RandomPracticeView: View {
    @Environment(PracticeSessionStore.self) private var practice
    @Environment(AppSettingsStore.self) private var settings
    @Environment(\.motion) private var motion
    /// Nil is the mixed practice, which covers every skill.
    @State private var skill: PracticeSkill?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                PunctuatedTitle(text: "Choose a skill")
                    .padding(.bottom, Spacing.l)

                VStack(spacing: Spacing.s) {
                    row(nil, title: "All skills", subtitle: "Mixed review", systemImage: "shuffle")
                    row(.reading, title: "Reading", subtitle: "Recognize words and meanings", systemImage: "book")
                    row(.writing, title: "Writing", subtitle: "Recall and spell words", systemImage: "pencil")
                    row(.listening, title: "Listening", subtitle: "Hear words, then pick or type them", systemImage: "headphones")
                    row(.speaking, title: "Speaking", subtitle: "Say words out loud", systemImage: "mic")
                }
            }
            .padding(.horizontal, Spacing.screenGutter)
            .padding(.top, Spacing.xs)
            .padding(.bottom, Spacing.l)
        }
        .background(Color.canvas)
        .safeAreaInset(edge: .bottom) {
            PinnedActionBar {
                PrimaryButton(title: "Start", action: start)
            }
        }
    }

    private func row(_ option: PracticeSkill?, title: LocalizedStringKey, subtitle: LocalizedStringKey, systemImage: String) -> some View {
        SkillOptionRow(title: title, subtitle: subtitle, systemImage: systemImage, isSelected: skill == option) {
            guard skill != option else { return }
            motion.perform(MotionTokens.snap) { skill = option }
            settings.feedback.selectionChanged()
        }
    }

    private func start() {
        Task {
            if let skill {
                await practice.startPractice(skill)
            } else {
                await practice.start(.randomPractice)
            }
        }
    }
}

private struct SkillOptionRow: View {
    let title: LocalizedStringKey
    let subtitle: LocalizedStringKey
    let systemImage: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: Radii.card - 2, style: .continuous)
        Button(action: action) {
            HStack(spacing: Spacing.s) {
                Image(systemName: systemImage)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(isSelected ? Color.white : Color.ink)
                    .frame(width: 48, height: 48)
                    .background(
                        isSelected ? Color.interactive : Color.neutralSurface,
                        in: RoundedRectangle(cornerRadius: Radii.tile, style: .continuous)
                    )
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: Spacing.xxs - 2) {
                    Text(title)
                        .font(Typography.emphasis)
                        .foregroundStyle(isSelected ? Color.selectedInk : Color.ink)
                    Text(subtitle)
                        .font(Typography.micro)
                        .foregroundStyle(Color.mutedInk)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .multilineTextAlignment(.leading)
                Spacer(minLength: 0)
            }
            .padding(Spacing.s)
            .background(isSelected ? Color.selectedSurface : Color.surface, in: shape)
            .overlay(shape.strokeBorder(isSelected ? Color.interactive : Color.stroke, lineWidth: 1.5))
            .contentShape(shape)
        }
        .buttonStyle(PressScaleButtonStyle())
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
