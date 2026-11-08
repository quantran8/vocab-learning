import AuthenticationServices
import SwiftUI

/// "or", then Sign in with Apple and Google, on the log-in screen. Either provider creates
/// the account on first use, so sign up offers only email and password.
struct SocialSignInButtons: View {
    @Environment(AuthStore.self) private var auth
    @Environment(\.webAuthenticationSession) private var webAuthenticationSession
    /// The raw nonce whose hash went into the pending Apple request.
    @State private var appleNonce: SignInNonce?

    var body: some View {
        VStack(spacing: Spacing.s) {
            HStack(spacing: Spacing.s) {
                Rectangle().fill(Color.stroke).frame(height: 1)
                Text("or")
                    .font(Typography.secondary)
                    .foregroundStyle(Color.mutedInk)
                Rectangle().fill(Color.stroke).frame(height: 1)
            }
            .accessibilityHidden(true)

            SignInWithAppleButton(.continue) { request in
                let nonce = SignInNonce()
                appleNonce = nonce
                request.requestedScopes = [.email]
                request.nonce = nonce.hashed
            } onCompletion: { result in
                handleApple(result)
            }
            .signInWithAppleButtonStyle(.black)
            .frame(height: Spacing.socialButtonHeight)
            .clipShape(RoundedRectangle(cornerRadius: Radii.primaryAction, style: .continuous))
            .disabled(auth.isSubmitting)

            Button(action: signInWithGoogle) {
                HStack(spacing: Spacing.xs) {
                    GoogleMark()
                        .frame(width: 18, height: 18)
                        .accessibilityHidden(true)
                    Text("Continue with Google")
                }
                .font(Typography.action)
                .foregroundStyle(Color.ink)
                .frame(maxWidth: .infinity, minHeight: Spacing.socialButtonHeight)
                .background(Color.surface, in: RoundedRectangle(cornerRadius: Radii.primaryAction, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: Radii.primaryAction, style: .continuous)
                        .strokeBorder(Color.stroke, lineWidth: 1.5)
                )
                .contentShape(RoundedRectangle(cornerRadius: Radii.primaryAction, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(auth.isSubmitting)
        }
    }

    private func handleApple(_ result: Result<ASAuthorization, Error>) {
        let nonce = appleNonce
        appleNonce = nil
        switch result {
        case .success(let authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                  let tokenData = credential.identityToken,
                  let token = String(data: tokenData, encoding: .utf8)
            else {
                auth.providerSignInFailed()
                return
            }
            Task { await auth.logIn(appleIDToken: token, nonce: nonce?.raw) }
        case .failure(let error):
            if (error as? ASAuthorizationError)?.code == .canceled { return }
            auth.providerSignInFailed()
        }
    }

    private func signInWithGoogle() {
        auth.clearError()
        Task {
            do {
                let result = try await GoogleSignIn.signIn(using: webAuthenticationSession)
                await auth.logIn(googleIDToken: result.idToken, nonce: result.nonce)
            } catch GoogleSignIn.Failure.cancelled {
                return
            } catch GoogleSignIn.Failure.notConfigured {
                auth.providerSignInFailed(String(localized: "Google sign-in isn’t set up yet.", bundle: .appLanguage))
            } catch {
                auth.providerSignInFailed()
            }
        }
    }
}

/// Google's four-colour "G", drawn so the button needs no image asset.
private struct GoogleMark: View {
    private static let blue = Color(red: 66 / 255, green: 133 / 255, blue: 244 / 255)
    private static let green = Color(red: 52 / 255, green: 168 / 255, blue: 83 / 255)
    private static let yellow = Color(red: 251 / 255, green: 188 / 255, blue: 5 / 255)
    private static let red = Color(red: 234 / 255, green: 67 / 255, blue: 53 / 255)

    var body: some View {
        GeometryReader { proxy in
            let size = min(proxy.size.width, proxy.size.height)
            let line = size * 0.2
            ZStack {
                // Trims start at 3 o'clock and run clockwise; the gap is the G's mouth.
                arc(0.0, 0.13, Self.blue, line)
                arc(0.13, 0.38, Self.green, line)
                arc(0.38, 0.56, Self.yellow, line)
                arc(0.56, 0.87, Self.red, line)
                Rectangle()
                    .fill(Self.blue)
                    .frame(width: size * 0.48, height: line)
                    .offset(x: size * 0.24 - line / 4)
            }
            .frame(width: size, height: size)
        }
    }

    private func arc(_ from: CGFloat, _ to: CGFloat, _ color: Color, _ line: CGFloat) -> some View {
        Circle()
            .trim(from: from, to: to)
            .stroke(color, style: StrokeStyle(lineWidth: line))
            .padding(line / 2)
    }
}
