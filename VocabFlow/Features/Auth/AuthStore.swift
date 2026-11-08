import Foundation
import Observation

@Observable
@MainActor
final class AuthStore {
    enum Phase: Equatable {
        case launching, signedOut, signedIn
    }

    static let passwordLength = 8...72

    private(set) var phase: Phase = .launching
    private(set) var isSubmitting = false
    private(set) var errorMessage: String?
    private(set) var isDeletingAccount = false
    private(set) var accountDeletionError: String?
    /// Shown on the sign-in screen after the account is gone.
    private(set) var accountDeletedNotice: String?
    /// Email awaiting confirmation after signing up.
    private(set) var pendingConfirmationEmail: String?
    /// Email a reset-password code was just sent to; the sign-in screen then asks for the code.
    private(set) var passwordResetEmail: String?
    private(set) var isChangingPassword = false
    private(set) var passwordChangeError: String?
    /// Clears per-account state. Runs on sign-out and when the session can't be refreshed.
    var onSignedOut: (@MainActor () -> Void)?
    /// Erases what this device remembers about the account, which signing out keeps.
    var onAccountDeleted: (@MainActor () -> Void)?

    private let api: VocabAPI

    init(api: VocabAPI) {
        self.api = api
    }

    func restore() async {
        guard phase == .launching else { return }
        phase = await api.hasStoredSession() ? .signedIn : .signedOut
    }

    func logIn(email: String, password: String) async {
        await submit {
            try await self.api.logIn(email: email, password: password)
            self.phase = .signedIn
        }
    }

    /// The token comes from Google Sign-In; pass the raw nonce if one was hashed into its request.
    func logIn(googleIDToken: String, nonce: String?) async {
        await submit(rejectedMessage: Self.providerRejected()) {
            try await self.api.logIn(googleIDToken: googleIDToken, nonce: nonce)
            self.phase = .signedIn
        }
    }

    /// The token comes from Sign in with Apple; pass the raw nonce whose hash went into its request.
    func logIn(appleIDToken: String, nonce: String?) async {
        await submit(rejectedMessage: Self.providerRejected()) {
            try await self.api.logIn(appleIDToken: appleIDToken, nonce: nonce)
            self.phase = .signedIn
        }
    }

    func requestPasswordReset(email: String) async {
        await submit {
            try await self.api.requestPasswordReset(email: email)
            self.passwordResetEmail = email
        }
    }

    func resetPassword(code: String, newPassword: String) async {
        guard let email = passwordResetEmail else { return }
        await submit {
            try await self.api.resetPassword(email: email, code: code, newPassword: newPassword)
            self.passwordResetEmail = nil
            self.phase = .signedIn
        }
    }

    func cancelPasswordReset() {
        passwordResetEmail = nil
        clearError()
    }

    /// Returns whether the password changed.
    func changePassword(current: String, new: String) async -> Bool {
        guard !isChangingPassword else { return false }
        isChangingPassword = true
        passwordChangeError = nil
        defer { isChangingPassword = false }
        do {
            try await api.changePassword(current: current, new: new)
            return true
        } catch {
            passwordChangeError = error.asAPIError.userMessage
            return false
        }
    }

    func clearPasswordChangeError() {
        passwordChangeError = nil
    }

    /// A Google or Apple sign-in that failed before reaching the backend.
    func providerSignInFailed(_ message: String? = nil) {
        errorMessage = message ?? Self.providerRejected()
    }

    func signUp(email: String, password: String) async {
        await submit {
            let result = try await self.api.signUp(email: email, password: password)
            if result.session != nil {
                self.phase = .signedIn
            } else if result.confirmationRequired {
                self.pendingConfirmationEmail = email
            }
        }
    }

    func dismissConfirmation() {
        pendingConfirmationEmail = nil
    }

    func clearError() {
        errorMessage = nil
        accountDeletedNotice = nil
    }

    func signOut() async {
        await api.signOut()
        sessionEnded()
    }

    func deleteAccount() async {
        guard !isDeletingAccount else { return }
        isDeletingAccount = true
        accountDeletionError = nil
        defer { isDeletingAccount = false }
        do {
            try await api.deleteAccount()
            accountDeletedNotice = String(localized: "Your account has been deleted.", bundle: .appLanguage)
        } catch let error as APIError where error.status == 401 {
            // Either the session expired or an earlier attempt succeeded and its answer was lost.
            errorMessage = String(localized: "Log in again to delete your account.", bundle: .appLanguage)
        } catch {
            accountDeletionError = error.asAPIError.userMessage
            return
        }
        await api.signOut()
        onAccountDeleted?()
        sessionEnded()
    }

    /// The refresh token was rejected.
    func sessionEnded() {
        guard phase != .signedOut else { return }
        phase = .signedOut
        onSignedOut?()
    }

    private static func providerRejected() -> String {
        String(localized: "Couldn’t sign in. Please try again.", bundle: .appLanguage)
    }

    /// `rejectedMessage` replaces "Wrong email or password." for a 401.
    private func submit(rejectedMessage: String? = nil, _ work: @escaping () async throws -> Void) async {
        guard !isSubmitting else { return }
        isSubmitting = true
        errorMessage = nil
        accountDeletedNotice = nil
        defer { isSubmitting = false }
        do {
            try await work()
        } catch let error as APIError where error.status == 401 {
            errorMessage = rejectedMessage ?? String(localized: "Wrong email or password.", bundle: .appLanguage)
        } catch {
            errorMessage = error.asAPIError.userMessage
        }
    }
}
