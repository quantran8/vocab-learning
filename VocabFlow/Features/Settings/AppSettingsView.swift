import SwiftUI

struct AppSettingsView: View {
    @Environment(AppSettingsStore.self) private var settings
    @Environment(TemplateSandboxStore.self) private var sandbox
    @Environment(\.motion) private var motion

    var body: some View {
        @Bindable var settings = settings

        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Eyebrow(text: "App preferences")

                PunctuatedTitle(text: "Settings")
                    .padding(.top, Spacing.xs)

                group("Interaction") {
                    SettingRow(systemImage: "iphone.radiowaves.left.and.right", title: "Haptics", subtitle: "Subtle touch feedback") {
                        Toggle("Haptics", isOn: $settings.hapticsEnabled)
                    }
                    SettingRow(systemImage: "circle.dotted.and.circle", title: "Reduce motion", subtitle: "Keep transitions minimal") {
                        Toggle("Reduce motion", isOn: $settings.reduceMotion)
                    }
                }

                group("App") {
                    SettingRow(systemImage: "circle.lefthalf.filled", title: "Appearance", subtitle: "Light theme") {
                        Text("Light")
                    }
                    Button {
                        motion.perform(MotionTokens.transition) { sandbox.openLab() }
                    } label: {
                        SettingRow(systemImage: "flask", title: "Practice Lab", subtitle: "Try exercise templates. Doesn’t affect your progress.") {
                            Image(systemName: "chevron.right")
                                .font(.subheadline.weight(.bold))
                                .accessibilityHidden(true)
                        }
                    }
                    .buttonStyle(.plain)
                    SettingRow(systemImage: "info.circle", title: "About Vocab Flow", subtitle: "Color Pop concept") {
                        Text(verbatim: "v\(appVersion)")
                    }
                }
            }
            .padding(.horizontal, Spacing.screenGutter)
            .padding(.top, Spacing.xs)
            .padding(.bottom, Spacing.l)
        }
        .background(Color.canvas)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func group<Content: View>(_ title: LocalizedStringKey, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Eyebrow(text: title)
                .accessibilityAddTraits(.isHeader)
                .padding(.bottom, Spacing.xxs)
            content()
        }
        .padding(.top, Spacing.l)
    }

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
    }
}

private struct SettingRow<Trailing: View>: View {
    let systemImage: String
    let title: LocalizedStringKey
    let subtitle: LocalizedStringKey
    @ViewBuilder let trailing: Trailing

    var body: some View {
        HStack(spacing: Spacing.s + 1) {
            RoundedRectangle(cornerRadius: Radii.chip + 2, style: .continuous)
                .fill(Color.neutralSurface)
                .frame(width: 40, height: 40)
                .overlay(
                    Image(systemName: systemImage)
                        .font(.body.weight(.medium))
                        .foregroundStyle(Color.ink)
                )
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(title)
                    .font(Typography.secondary.weight(.bold))
                    .foregroundStyle(Color.ink)
                Text(subtitle)
                    .font(Typography.micro)
                    .foregroundStyle(Color.mutedInk)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: Spacing.xs)
            trailing
                .labelsHidden()
                .tint(Color.interactive)
                .font(Typography.micro)
                .foregroundStyle(Color.mutedInk)
        }
        .frame(minHeight: 69)
        .contentShape(Rectangle())
        .overlay(alignment: .bottom) {
            Rectangle().fill(Color.neutralSurface).frame(height: 1)
        }
    }
}
