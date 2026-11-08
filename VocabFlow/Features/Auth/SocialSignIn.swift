import AuthenticationServices
import CryptoKit
import Foundation
// `WebAuthenticationSession` lives in the AuthenticationServices + SwiftUI cross-import overlay.
import SwiftUI

/// A one-time value for an ID-token request: the provider gets its SHA-256, the backend the raw value.
struct SignInNonce {
    let raw: String

    init() {
        var bytes = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        raw = Data(bytes).base64URLEncoded
    }

    var hashed: String { Self.sha256Hex(raw) }

    static func sha256Hex(_ value: String) -> String {
        SHA256.hash(data: Data(value.utf8)).map { String(format: "%02x", $0) }.joined()
    }
}

/// Google sign-in without the SDK: OAuth code flow with PKCE in the system web-auth sheet,
/// then the code is exchanged for an ID token (iOS clients have no secret).
struct GoogleSignIn {
    enum Failure: Error {
        case notConfigured, cancelled, rejected
    }

    struct Result {
        let idToken: String
        let nonce: String
    }

    /// The iOS OAuth client ID (`….apps.googleusercontent.com`), from Info.plist `GoogleClientID`.
    static var clientID: String? {
        let value = (Bundle.main.object(forInfoDictionaryKey: "GoogleClientID") as? String)?
            .trimmingCharacters(in: .whitespaces)
        guard let value, value.hasSuffix(".apps.googleusercontent.com") else { return nil }
        return value
    }

    @MainActor
    static func signIn(using session: WebAuthenticationSession) async throws -> Result {
        guard let clientID else { throw Failure.notConfigured }
        // Google's iOS clients redirect to the reversed client ID.
        let scheme = clientID.split(separator: ".").reversed().joined(separator: ".")
        let redirectURI = "\(scheme):/oauth2redirect"
        let verifier = SignInNonce().raw + SignInNonce().raw
        let challenge = Data(SHA256.hash(data: Data(verifier.utf8))).base64URLEncoded
        let state = SignInNonce().raw
        let nonce = SignInNonce()

        var components = URLComponents(string: "https://accounts.google.com/o/oauth2/v2/auth")!
        components.queryItems = [
            URLQueryItem(name: "client_id", value: clientID),
            URLQueryItem(name: "redirect_uri", value: redirectURI),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: "openid email profile"),
            URLQueryItem(name: "code_challenge", value: challenge),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
            URLQueryItem(name: "state", value: state),
            URLQueryItem(name: "nonce", value: nonce.hashed),
            URLQueryItem(name: "prompt", value: "select_account"),
        ]

        let callback: URL
        do {
            callback = try await session.authenticate(
                using: components.url!,
                callbackURLScheme: scheme,
                preferredBrowserSession: .shared
            )
        } catch let error as ASWebAuthenticationSessionError where error.code == .canceledLogin {
            throw Failure.cancelled
        }

        let items = URLComponents(url: callback, resolvingAgainstBaseURL: false)?.queryItems ?? []
        guard items.first(where: { $0.name == "state" })?.value == state,
              let code = items.first(where: { $0.name == "code" })?.value
        else { throw Failure.rejected }

        var request = URLRequest(url: URL(string: "https://oauth2.googleapis.com/token")!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        var form = URLComponents()
        form.queryItems = [
            URLQueryItem(name: "code", value: code),
            URLQueryItem(name: "client_id", value: clientID),
            URLQueryItem(name: "redirect_uri", value: redirectURI),
            URLQueryItem(name: "grant_type", value: "authorization_code"),
            URLQueryItem(name: "code_verifier", value: verifier),
        ]
        request.httpBody = Data((form.percentEncodedQuery ?? "").utf8)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200,
              let token = try? JSONDecoder().decode(TokenResponse.self, from: data)
        else { throw Failure.rejected }
        return Result(idToken: token.idToken, nonce: nonce.raw)
    }

    private struct TokenResponse: Decodable {
        let idToken: String

        enum CodingKeys: String, CodingKey {
            case idToken = "id_token"
        }
    }
}

private extension Data {
    var base64URLEncoded: String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
