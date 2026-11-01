import Foundation

enum APIError: Error, Equatable {
    /// The backend answered with its `{code, message, retryable, requestId}` error body.
    case server(status: Int, code: String, message: String, retryable: Bool, requestID: String?)
    /// No usable answer arrived, so the request may or may not have taken effect.
    case transport
    /// The answer doesn't match the contract, including a template this build can't render.
    case invalidResponse

    var code: String? {
        if case .server(_, let code, _, _, _) = self { return code }
        return nil
    }

    var status: Int? {
        if case .server(let status, _, _, _, _) = self { return status }
        return nil
    }

    var isRetryable: Bool {
        switch self {
        case .server(_, _, _, let retryable, _): retryable
        case .transport: true
        case .invalidResponse: false
        }
    }

    var userMessage: String {
        switch self {
        case .transport:
            String(localized: "Can’t reach Vocab Flow. Check your connection and try again.")
        case .invalidResponse:
            String(localized: "Something went wrong on our side. Please try again later.")
        case .server(_, let code, let message, _, let requestID):
            switch code {
            case "EMAIL_ALREADY_REGISTERED":
                String(localized: "This email already has an account. Try logging in.")
            case "VALIDATION_FAILED":
                message
            case "CUSTOM_WORD_LIMIT_REACHED":
                String(localized: "You can’t add more words right now. Please try again later.")
            case "CUSTOM_WORD_UNAVAILABLE":
                String(localized: "That meaning is no longer available.")
            case "LEXICAL_PROVIDER_UNAVAILABLE":
                String(localized: "We couldn’t prepare this word just now. Please try again.")
            default:
                requestID.map { String(localized: "Something went wrong. Reference: \($0)") }
                    ?? String(localized: "Something went wrong. Please try again.")
            }
        }
    }
}

extension Error {
    var asAPIError: APIError { self as? APIError ?? .transport }
}
