import SwiftUI

/// Pushed from My Words' Random Practice tile. Nothing is planned until Start.
struct RandomPracticeView: View {
    @Environment(PracticeSessionStore.self) private var practice
    @Environment(AppSettingsStore.self) private var settings
    @Environment(\.motion) private var motion
    /// Empty is the mixed practice, which covers every skill.
    @State private var skills: Set<PracticeSkill> = []

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                PunctuatedTitle(text: "Choose skills")
                    .padding(.bottom, Spacing.xs)
                Text("Pick one or more")
                    .font(Typography.secondary)
                    .foregroundStyle(Color.mutedInk)
                    .padding(.bottom, Spacing.l)

                VStack(spacing: Spacing.s) {
                    SkillOptionRow(title: "All skills", subtitle: "Mixed review", systemImage: "shuffle", isSelected: skills.isEmpty, action: selectAll)
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

    private func row(_ option: PracticeSkill, title: LocalizedStringKey, subtitle: LocalizedStringKey, systemImage: String) -> some View {
        SkillOptionRow(
            title: title, subtitle: subtitle, systemImage: systemImage,
            isSelected: skills.contains(option), showsCheckbox: true
        ) {
            motion.perform(MotionTokens.snap) {
                if skills.contains(option) { skills.remove(option) } else { skills.insert(option) }
            }
            settings.feedback.selectionChanged()
        }
    }

    private func selectAll() {
        guard !skills.isEmpty else { return }
        motion.perform(MotionTokens.snap) { skills = [] }
        settings.feedback.selectionChanged()
    }

    private func start() {
        // Wire order follows the enum so the same choice always sends the same request.
        let chosen = PracticeSkill.allCases.filter(skills.contains)
        Task {
            if chosen.isEmpty {
                await practice.start(.randomPractice)
            } else {
                await practice.startPractice(chosen)
            }
        }
    }
}

private struct SkillOptionRow: View {
    let title: LocalizedStringKey
    let subtitle: LocalizedStringKey
    let systemImage: String
    let isSelected: Bool
    /// Skill rows can be combined, so they show a checkbox; "All skills" can't.
    var showsCheckbox = false
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
                if showsCheckbox {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(isSelected ? Color.interactive : Color.stroke)
                        .accessibilityHidden(true)
                }
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
