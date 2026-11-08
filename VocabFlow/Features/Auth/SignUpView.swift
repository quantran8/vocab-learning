import SwiftUI

/// Creating an account with email and password, pushed from the log-in screen.
struct SignUpView: View {
    private enum Field {
        case email, password
    }

    @Environment(AuthStore.self) private var auth
    @Environment(\.dismiss) private var dismiss
    @Binding var email: String
    @State private var password = ""
    @FocusState private var focus: Field?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                PunctuatedTitle(text: "Create your account")
                    .padding(.top, Spacing.s)
                    .padding(.bottom, Spacing.l)

                if let confirmation = auth.pendingConfirmationEmail {
                    confirmationNotice(confirmation)
                } else {
                    form
                }
            }
            .padding(.horizontal, Spacing.screenGutter)
            .padding(.bottom, Spacing.l)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Color.canvas)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .onAppear { auth.clearError() }
        .onDisappear {
            auth.clearError()
            auth.dismissConfirmation()
        }
    }

    private var form: some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            LabeledField("Email") {
                TextField("you@example.com", text: $email)
                    .keyboardType(.emailAddress)
                    .textContentType(.username)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.next)
                    .focused($focus, equals: .email)
                    .onSubmit { focus = .password }
            }
            VStack(alignment: .leading, spacing: Spacing.s) {
                LabeledField("Password") {
                    PasswordInput(
                        placeholder: "Create a password",
                        text: $password,
                        contentType: .newPassword,
                        focus: $focus,
                        field: .password,
                        onSubmit: submit
                    )
                }
                PasswordRuleList(password: password)
            }
            if let error = auth.errorMessage {
                Text(verbatim: error)
                    .font(Typography.secondary)
                    .foregroundStyle(Color.errorInk)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if auth.isSubmitting {
                ProgressView()
                    .frame(maxWidth: .infinity)
            }
            VStack(spacing: Spacing.xs) {
                PrimaryButton(title: "Sign up", isEnabled: canSubmit, action: submit)
                Button {
                    dismiss()
                } label: {
                    Text("Already have an account? Log in")
                        .font(Typography.secondary.weight(.bold))
                        .foregroundStyle(Color.selectedInk)
                        .frame(maxWidth: .infinity, minHeight: Spacing.minTouchTarget)
                }
            }
            .padding(.top, Spacing.xs)
        }
    }

    private func confirmationNotice(_ address: String) -> some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            Text("Check your email")
                .font(Typography.emphasis)
                .foregroundStyle(Color.ink)
            Text("We sent a confirmation link to \(address). Open it, then log in.")
                .font(Typography.body)
                .foregroundStyle(Color.mutedInk)
                .fixedSize(horizontal: false, vertical: true)
            PrimaryButton(title: "Back to log in") {
                dismiss()
            }
        }
    }

    private var canSubmit: Bool {
        !auth.isSubmitting
            && !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && PasswordPolicy.accepts(password)
    }

    private func submit() {
        guard canSubmit else { return }
        focus = nil
        let email = email.trimmingCharacters(in: .whitespacesAndNewlines)
        Task { await auth.signUp(email: email, password: password) }
    }
}
