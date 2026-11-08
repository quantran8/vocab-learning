import SwiftUI

/// Changes the password of the signed-in account. The backend re-checks the current one.
struct ChangePasswordSheet: View {
    private enum Field {
        case current, new
    }

    @Environment(AuthStore.self) private var auth
    @Environment(\.dismiss) private var dismiss
    @State private var current = ""
    @State private var new = ""
    @State private var didChange = false
    @FocusState private var focus: Field?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.m) {
                HStack {
                    PunctuatedTitle(text: "Change password", font: Typography.screenTitle)
                    Spacer(minLength: Spacing.xs)
                    SheetCloseButton()
                }

                if didChange {
                    Label("Your password has been changed.", systemImage: "checkmark.circle.fill")
                        .font(Typography.body)
                        .foregroundStyle(Color.successInk)
                    PrimaryButton(title: "Done") { dismiss() }
                } else {
                    form
                }
            }
            .padding(.horizontal, Spacing.screenGutter)
            .padding(.top, Spacing.m)
            .padding(.bottom, Spacing.l)
        }
        .scrollDismissesKeyboard(.interactively)
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .presentationBackground(Color.canvas)
        .onAppear {
            auth.clearPasswordChangeError()
            focus = .current
        }
    }

    private var form: some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            LabeledField("Current password") {
                PasswordInput(
                    placeholder: "Current password",
                    text: $current,
                    contentType: .password,
                    focus: $focus,
                    field: .current,
                    submitLabel: .next
                ) { focus = .new }
            }
            VStack(alignment: .leading, spacing: Spacing.s) {
                LabeledField("New password") {
                    PasswordInput(
                        placeholder: "Create a password",
                        text: $new,
                        contentType: .newPassword,
                        focus: $focus,
                        field: .new,
                        submitLabel: .done,
                        onSubmit: submit
                    )
                }
                PasswordRuleList(password: new)
            }
            Text("Signed up with Google or Apple? Log out and use “Forgot password?” to set a password.")
                .font(Typography.micro)
                .foregroundStyle(Color.mutedInk)
                .fixedSize(horizontal: false, vertical: true)
            if let error = auth.passwordChangeError {
                Text(verbatim: error)
                    .font(Typography.secondary)
                    .foregroundStyle(Color.errorInk)
                    .fixedSize(horizontal: false, vertical: true)
            }
            PrimaryButton(title: "Change password", isEnabled: canSubmit, action: submit)
                .padding(.top, Spacing.xs)
            if auth.isChangingPassword {
                ProgressView()
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private var canSubmit: Bool {
        !auth.isChangingPassword
            && AuthStore.passwordLength.contains(current.count)
            && PasswordPolicy.accepts(new)
    }

    private func submit() {
        guard canSubmit else { return }
        focus = nil
        Task {
            if await auth.changePassword(current: current, new: new) {
                current = ""
                new = ""
                didChange = true
            }
        }
    }
}
