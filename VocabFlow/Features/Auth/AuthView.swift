import SwiftUI

/// Email sign-in and sign-up on one screen; only the pinned action and its wording change.
struct AuthView: View {
    private enum Mode {
        case logIn, signUp
    }

    private enum Field {
        case email, password
    }

    @Environment(AuthStore.self) private var auth
    @Environment(\.motion) private var motion
    @State private var mode = Mode.logIn
    @State private var email = ""
    @State private var password = ""
    @FocusState private var focus: Field?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                BrandBar()

                PunctuatedTitle(text: mode == .logIn ? "Welcome back" : "Create your account")
                    .padding(.top, Spacing.xl + Spacing.s)
                    .padding(.bottom, Spacing.l)

                if let confirmation = auth.pendingConfirmationEmail {
                    confirmationNotice(confirmation)
                } else {
                    form
                }
            }
            .padding(.horizontal, Spacing.screenGutter)
            .padding(.top, Spacing.s)
            .padding(.bottom, Spacing.l)
        }
        .scrollDismissesKeyboard(.interactively)
        .safeAreaInset(edge: .bottom) {
            if auth.pendingConfirmationEmail == nil {
                PinnedActionBar {
                    VStack(spacing: Spacing.xs) {
                        PrimaryButton(
                            title: mode == .logIn ? "Log in" : "Sign up",
                            requirement: "Enter your email and a password of at least 8 characters",
                            isEnabled: canSubmit
                        ) {
                            submit()
                        }
                        Button {
                            auth.clearError()
                            motion.perform(MotionTokens.snap) { mode = mode == .logIn ? .signUp : .logIn }
                        } label: {
                            Text(mode == .logIn ? "New here? Create an account" : "Already have an account? Log in")
                                .font(Typography.secondary.weight(.bold))
                                .foregroundStyle(Color.selectedInk)
                                .frame(maxWidth: .infinity, minHeight: Spacing.minTouchTarget)
                        }
                    }
                }
            }
        }
    }

    private var form: some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            field("Email") {
                TextField("you@example.com", text: $email)
                    .keyboardType(.emailAddress)
                    .textContentType(.username)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.next)
                    .focused($focus, equals: .email)
                    .onSubmit { focus = .password }
            }
            field("Password") {
                SecureField("At least 8 characters", text: $password)
                    .textContentType(mode == .logIn ? .password : .newPassword)
                    .submitLabel(.go)
                    .focused($focus, equals: .password)
                    .onSubmit(submit)
            }
            if let notice = auth.accountDeletedNotice {
                Text(verbatim: notice)
                    .font(Typography.secondary)
                    .foregroundStyle(Color.ink)
                    .fixedSize(horizontal: false, vertical: true)
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
        }
    }

    private func field<Content: View>(_ title: LocalizedStringKey, @ViewBuilder content: () -> Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: Radii.tile, style: .continuous)
        return VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(title)
                .font(Typography.secondary.weight(.semibold))
                .foregroundStyle(Color.ink)
            content()
                .font(Typography.body)
                .foregroundStyle(Color.ink)
                .padding(.horizontal, Spacing.m)
                .frame(minHeight: Spacing.tileMinHeight)
                .background(Color.surface, in: shape)
                .overlay(shape.strokeBorder(Color.stroke, lineWidth: 1.5))
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
                motion.perform(MotionTokens.snap) {
                    mode = .logIn
                    auth.dismissConfirmation()
                }
            }
        }
    }

    private var canSubmit: Bool {
        !auth.isSubmitting
            && !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && AuthStore.passwordLength.contains(password.count)
    }

    private func submit() {
        guard canSubmit else { return }
        focus = nil
        let email = email.trimmingCharacters(in: .whitespacesAndNewlines)
        Task {
            if mode == .logIn {
                await auth.logIn(email: email, password: password)
            } else {
                await auth.signUp(email: email, password: password)
            }
        }
    }
}
