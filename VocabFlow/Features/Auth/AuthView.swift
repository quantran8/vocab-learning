import SwiftUI

/// Log in with email and password, Apple or Google, and reset a forgotten password.
/// Creating an account is pushed as `SignUpView`.
struct AuthView: View {
    private enum Field {
        case email, code, password
    }

    /// The reset has two steps; the store knows whether the code went out.
    private enum Step {
        case logIn, resetEmail, resetCode
    }

    @Environment(AuthStore.self) private var auth
    @Environment(\.motion) private var motion
    @State private var isResetting = false
    @State private var isSigningUp = false
    @State private var email = ""
    @State private var password = ""
    @State private var resetCode = ""
    @FocusState private var focus: Field?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.m) {
                    BrandBar()
                        .padding(.bottom, Spacing.l)

                    switch step {
                    case .logIn: logInForm
                    case .resetEmail: resetEmailForm
                    case .resetCode: resetCodeForm
                    }
                }
                .padding(.horizontal, Spacing.screenGutter)
                .padding(.top, Spacing.s)
                .padding(.bottom, Spacing.l)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Color.canvas)
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(isPresented: $isSigningUp) {
                SignUpView(email: $email)
            }
        }
        .tint(Color.ink)
    }

    // MARK: - Steps

    @ViewBuilder
    private var logInForm: some View {
        emailField(submitLabel: .next) { focus = .password }
        VStack(alignment: .trailing, spacing: Spacing.xxs) {
            LabeledField("Password") {
                PasswordInput(
                    placeholder: "At least 8 characters",
                    text: $password,
                    contentType: .password,
                    focus: $focus,
                    field: .password,
                    onSubmit: submit
                )
            }
            Button("Forgot password?") { setResetting(true) }
                .font(Typography.secondary.weight(.semibold))
                .foregroundStyle(Color.selectedInk)
                .frame(minHeight: Spacing.minTouchTarget)
        }
        messages
        actions(
            title: "Log in",
            link: "New here? Create an account"
        ) {
            auth.clearError()
            isSigningUp = true
        }
        SocialSignInButtons()
            .padding(.top, Spacing.xs)
    }

    @ViewBuilder
    private var resetEmailForm: some View {
        PunctuatedTitle(text: "Reset your password")
            .padding(.bottom, Spacing.xs)
        emailField(submitLabel: .send, onSubmit: submit)
        Text("Enter the email you signed up with. We’ll send you a code to set a new password.")
            .font(Typography.secondary)
            .foregroundStyle(Color.mutedInk)
            .fixedSize(horizontal: false, vertical: true)
        messages
        actions(title: "Send code", link: "Back to log in") { setResetting(false) }
    }

    @ViewBuilder
    private var resetCodeForm: some View {
        PunctuatedTitle(text: "Reset your password")
            .padding(.bottom, Spacing.xs)
        Text("We sent a code to \(auth.passwordResetEmail ?? email). Enter it and choose a new password.")
            .font(Typography.secondary)
            .foregroundStyle(Color.mutedInk)
            .fixedSize(horizontal: false, vertical: true)
        VStack(alignment: .trailing, spacing: Spacing.xxs) {
            LabeledField("Code") {
                TextField("6-digit code", text: $resetCode)
                    .keyboardType(.numberPad)
                    .textContentType(.oneTimeCode)
                    .focused($focus, equals: .code)
            }
            Button("Send a new code") {
                Task { await auth.requestPasswordReset(email: auth.passwordResetEmail ?? email) }
            }
            .font(Typography.secondary.weight(.semibold))
            .foregroundStyle(Color.selectedInk)
            .frame(minHeight: Spacing.minTouchTarget)
            .disabled(auth.isSubmitting)
        }
        VStack(alignment: .leading, spacing: Spacing.s) {
            LabeledField("New password") {
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
        messages
        actions(title: "Set new password", link: "Back to log in") { setResetting(false) }
    }

    // MARK: - Pieces

    private func emailField(submitLabel: SubmitLabel, onSubmit: @escaping () -> Void) -> some View {
        LabeledField("Email") {
            TextField("you@example.com", text: $email)
                .keyboardType(.emailAddress)
                .textContentType(.username)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(submitLabel)
                .focused($focus, equals: .email)
                .onSubmit(onSubmit)
        }
    }

    @ViewBuilder
    private var messages: some View {
        if let notice = auth.accountDeletedNotice {
            Text(verbatim: notice)
                .font(Typography.secondary)
                .foregroundStyle(Color.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
        // Errors from the sign-up screen stay there.
        if !isSigningUp, let error = auth.errorMessage {
            Text(verbatim: error)
                .font(Typography.secondary)
                .foregroundStyle(Color.errorInk)
                .fixedSize(horizontal: false, vertical: true)
        }
        if auth.isSubmitting && !isSigningUp {
            ProgressView()
                .frame(maxWidth: .infinity)
        }
    }

    private func actions(title: LocalizedStringKey, link: LocalizedStringKey, onLink: @escaping () -> Void) -> some View {
        VStack(spacing: Spacing.xs) {
            PrimaryButton(title: title, isEnabled: canSubmit, action: submit)
            Button(action: onLink) {
                Text(link)
                    .font(Typography.secondary.weight(.bold))
                    .foregroundStyle(Color.selectedInk)
                    .frame(maxWidth: .infinity, minHeight: Spacing.minTouchTarget)
            }
        }
        .padding(.top, Spacing.xs)
    }

    // MARK: - State

    private var step: Step {
        guard isResetting else { return .logIn }
        return auth.passwordResetEmail == nil ? .resetEmail : .resetCode
    }

    private var trimmedEmail: String {
        email.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var trimmedCode: String {
        resetCode.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canSubmit: Bool {
        guard !auth.isSubmitting else { return false }
        switch step {
        case .logIn: return !trimmedEmail.isEmpty && AuthStore.passwordLength.contains(password.count)
        case .resetEmail: return !trimmedEmail.isEmpty
        case .resetCode: return !trimmedCode.isEmpty && PasswordPolicy.accepts(password)
        }
    }

    private func setResetting(_ resetting: Bool) {
        if !resetting { auth.cancelPasswordReset() }
        auth.clearError()
        motion.perform(MotionTokens.snap) {
            isResetting = resetting
            // The reset's new password must not reuse what was typed to log in, or vice versa.
            password = ""
            resetCode = ""
        }
    }

    private func submit() {
        guard canSubmit else { return }
        focus = nil
        let email = trimmedEmail
        Task {
            switch step {
            case .logIn: await auth.logIn(email: email, password: password)
            case .resetEmail: await auth.requestPasswordReset(email: email)
            case .resetCode: await auth.resetPassword(code: trimmedCode, newPassword: password)
            }
        }
    }
}
