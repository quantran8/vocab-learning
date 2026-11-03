import SwiftUI

struct AppSettingsView: View {
    @Environment(AppSettingsStore.self) private var settings
    @Environment(TemplateSandboxStore.self) private var sandbox
    @Environment(AuthStore.self) private var auth
    @Environment(\.motion) private var motion
    @State private var isConfirmingDeletion = false

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

                group("Account") {
                    Button {
                        Task { await auth.signOut() }
                    } label: {
                        SettingRow(systemImage: "rectangle.portrait.and.arrow.right", title: "Log out", subtitle: "Your progress stays on your account") {
                            EmptyView()
                        }
                    }
                    .buttonStyle(.plain)
                    .disabled(auth.isDeletingAccount)
                    Button {
                        isConfirmingDeletion = true
                    } label: {
                        SettingRow(systemImage: "trash", title: "Delete account", subtitle: "Permanently removes your account and all your data", tint: .errorInk) {
                            if auth.isDeletingAccount {
                                ProgressView()
                                    .accessibilityLabel("Deleting your account")
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .disabled(auth.isDeletingAccount)
                    if let error = auth.accountDeletionError {
                        Text(verbatim: error)
                            .font(Typography.secondary)
                            .foregroundStyle(Color.errorInk)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.top, Spacing.xs)
                    }
                }
            }
            .padding(.horizontal, Spacing.screenGutter)
            .padding(.top, Spacing.xs)
            .padding(.bottom, Spacing.l)
        }
        .background(Color.canvas)
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog("Delete your account?", isPresented: $isConfirmingDeletion, titleVisibility: .visible) {
            Button("Delete account", role: .destructive) {
                Task { await auth.deleteAccount() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Your progress, words and settings will be permanently deleted. This can’t be undone.")
        }
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
    var tint: Color = .ink
    @ViewBuilder let trailing: Trailing

    var body: some View {
        HStack(spacing: Spacing.s + 1) {
            RoundedRectangle(cornerRadius: Radii.chip + 2, style: .continuous)
                .fill(Color.neutralSurface)
                .frame(width: 40, height: 40)
                .overlay(
                    Image(systemName: systemImage)
                        .font(.body.weight(.medium))
                        .foregroundStyle(tint)
                )
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(title)
                    .font(Typography.secondary.weight(.bold))
                    .foregroundStyle(tint)
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
