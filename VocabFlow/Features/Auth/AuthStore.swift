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
    /// Email awaiting confirmation after signing up.
    private(set) var pendingConfirmationEmail: String?
    /// Clears per-account state. Runs on sign-out and when the session can't be refreshed.
    var onSignedOut: (@MainActor () -> Void)?

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
        await submit {
            try await self.api.logIn(googleIDToken: googleIDToken, nonce: nonce)
            self.phase = .signedIn
        }
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
    }

    func signOut() async {
        await api.signOut()
        sessionEnded()
    }

    /// The refresh token was rejected.
    func sessionEnded() {
        guard phase != .signedOut else { return }
        phase = .signedOut
        onSignedOut?()
    }

    private func submit(_ work: @escaping () async throws -> Void) async {
        guard !isSubmitting else { return }
        isSubmitting = true
        errorMessage = nil
        defer { isSubmitting = false }
        do {
            try await work()
        } catch let error as APIError where error.status == 401 {
            errorMessage = String(localized: "Wrong email or password.")
        } catch {
            errorMessage = error.asAPIError.userMessage
        }
    }
}
