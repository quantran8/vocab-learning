import SwiftUI

struct PracticeLabView: View {
    @Environment(TemplateSandboxStore.self) private var sandbox
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

                filters

                VStack(spacing: Spacing.s) {
                    ForEach(sandbox.visibleTemplates) { template in
                        TemplateCard(template: template) {
                            motion.perform(MotionTokens.transition) { sandbox.open(template.id) }
                        }
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
            .padding(.horizontal, Spacing.screenGutter - Spacing.xs)
            .background(Color.canvas)
        }
    }

    private var filters: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Spacing.xs) {
                filterChip(nil, title: "All")
                ForEach(TemplateCategory.allCases) { category in
                    filterChip(category, title: category.title)
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text("Category filter"))
    }

    private func filterChip(_ category: TemplateCategory?, title: LocalizedStringKey) -> some View {
        let isSelected = sandbox.category == category
        let count = category.map { kind in sandbox.library.templates.filter { $0.category == kind }.count } ?? sandbox.library.templates.count
        return Button {
            motion.perform(MotionTokens.feedback) { sandbox.category = category }
        } label: {
            HStack(spacing: Spacing.xxs + 2) {
                Text(title)
                Text(verbatim: "\(count)")
                    .foregroundStyle(isSelected ? Color.white.opacity(0.75) : Color.mutedInk)
            }
            .font(Typography.secondary.weight(.bold))
            .foregroundStyle(isSelected ? Color.white : Color.ink)
            .padding(.horizontal, Spacing.m)
            .frame(minHeight: Spacing.minTouchTarget)
            .background(isSelected ? Color.ink : Color.surface, in: RoundedRectangle(cornerRadius: Radii.chip, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Radii.chip, style: .continuous).strokeBorder(isSelected ? Color.clear : Color.stroke, lineWidth: 1.5))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}

private struct TemplateCard: View {
    let template: TemplateDefinition
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
                        Chip(text: template.category.title)
                    }
                    Text(verbatim: template.action)
                        .font(Typography.secondary)
                        .foregroundStyle(Color.mutedInk)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                    if template.exercises.count > 1 {
                        Text("\(template.exercises.count) examples")
                            .font(Typography.micro.weight(.semibold))
                            .foregroundStyle(Color.selectedInk)
                    }
                }
            }
            .padding(Spacing.m)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(ChunkyButtonStyle(kind: .secondary))
        .accessibilityElement(children: .combine)
        .accessibilityHint(Text("Opens the exercise."))
    }
}

struct BackButton: View {
    let label: LocalizedStringKey
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.xxs) {
                Image(systemName: "chevron.left")
                    .font(.body.weight(.bold))
                Text(label)
                    .font(Typography.secondary.weight(.bold))
            }
            .foregroundStyle(Color.ink)
            .padding(.horizontal, Spacing.xs)
            .frame(minHeight: Spacing.minTouchTarget)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

extension TemplateCategory {
    var title: LocalizedStringKey {
        switch self {
        case .classic: "Classic"
        case .creative: "Creative"
        case .skill: "Skill"
        }
    }
}
