import Foundation

struct APIRequest {
    enum Method: String {
        case get = "GET", post = "POST", put = "PUT", delete = "DELETE"
    }

    var method: Method
    var path: String
    var query: [URLQueryItem] = []
    var body: Data?
    var contentType = "application/json"
    var requiresAuth = true
    /// Extra attempts after a retryable failure. Only for requests that are safe to repeat.
    var retries = 0
    /// Overrides the session's timeout, for requests the backend answers slowly.
    var timeout: TimeInterval?
}

/// HTTP transport: bearer auth, one refresh-and-retry on 401, backoff on retryable failures.
/// An actor so concurrent 401s share a single refresh; refresh tokens are single use.
actor APIClient {
    /// Refresh this long before expiry instead of waiting for a 401.
    private static let expiryMargin: TimeInterval = 60

    private let baseURL: URL
    private let session: URLSession
    private let tokens: TokenStoring
    private let now: () -> Date
    private let pause: (Duration) async -> Void
    private var refreshTask: Task<AuthTokens, Error>?
    private var onSessionEnded: (@MainActor () -> Void)?

    static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let text = try container.decode(String.self)
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = formatter.date(from: text) { return date }
            formatter.formatOptions = [.withInternetDateTime]
            if let date = formatter.date(from: text) { return date }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid ISO 8601 date")
        }
        return decoder
    }()

    init(
        baseURL: URL,
        tokens: TokenStoring,
        session: URLSession = .shared,
        now: @escaping () -> Date = Date.init,
        pause: @escaping (Duration) async -> Void = { try? await Task.sleep(for: $0) }
    ) {
        self.baseURL = baseURL
        self.tokens = tokens
        self.session = session
        self.now = now
        self.pause = pause
    }

    /// Called when the refresh token is rejected, so the app can return to sign-in.
    func setSessionEndedHandler(_ handler: @escaping @MainActor () -> Void) {
        onSessionEnded = handler
    }

    var hasStoredSession: Bool { tokens.load() != nil }

    func store(_ session: AuthSession) {
        tokens.save(authTokens(from: session))
    }

    func signOut() {
        refreshTask?.cancel()
        refreshTask = nil
        tokens.clear()
    }

    func send<Response: Decodable>(_ request: APIRequest) async throws -> Response {
        let data = try await sendRaw(request)
        do {
            return try Self.decoder.decode(Response.self, from: data)
        } catch {
            throw APIError.invalidResponse
        }
    }

    func sendRaw(_ request: APIRequest) async throws -> Data {
        var attempt = 0
        while true {
            do {
                return try await authorized(request)
            } catch let error as APIError where error.isRetryable && attempt < request.retries {
                attempt += 1
                await pause(.milliseconds(500 << attempt))
            }
        }
    }

    // MARK: Auth

    private func authorized(_ request: APIRequest) async throws -> Data {
        guard request.requiresAuth else { return try await execute(request, accessToken: nil) }
        let token = try await currentAccessToken()
        do {
            return try await execute(request, accessToken: token)
        } catch let error as APIError where error.status == 401 {
            let fresh = try await refreshed(replacing: token)
            return try await execute(request, accessToken: fresh)
        }
    }

    private func currentAccessToken() async throws -> String {
        guard let current = tokens.load() else { throw Self.unauthorized }
        if current.expiresAt.timeIntervalSince(now()) > Self.expiryMargin {
            return current.accessToken
        }
        return try await refreshed(replacing: current.accessToken)
    }

    private func refreshed(replacing staleToken: String) async throws -> String {
        if let refreshTask {
            return try await refreshTask.value.accessToken
        }
        guard let current = tokens.load() else { throw Self.unauthorized }
        // Another request already rotated the pair while this one was in flight.
        if current.accessToken != staleToken {
            return current.accessToken
        }
        let task = Task { try await self.rotate(current.refreshToken) }
        refreshTask = task
        defer { refreshTask = nil }
        return try await task.value.accessToken
    }

    private func rotate(_ refreshToken: String) async throws -> AuthTokens {
        var request = APIRequest(method: .post, path: "auth/refresh", requiresAuth: false)
        request.body = try JSONEncoder().encode(RefreshRequest(refreshToken: refreshToken))
        do {
            let data = try await execute(request, accessToken: nil)
            guard let session = try? Self.decoder.decode(AuthSession.self, from: data) else {
                throw APIError.invalidResponse
            }
            let fresh = authTokens(from: session)
            try Task.checkCancellation()
            tokens.save(fresh)
            return fresh
        } catch let error as APIError where error.status == 401 {
            tokens.clear()
            if let onSessionEnded {
                await onSessionEnded()
            }
            throw error
        }
    }

    private func authTokens(from session: AuthSession) -> AuthTokens {
        AuthTokens(
            accessToken: session.accessToken,
            refreshToken: session.refreshToken,
            expiresAt: now().addingTimeInterval(TimeInterval(session.expiresIn))
        )
    }

    private static let unauthorized = APIError.server(
        status: 401, code: "UNAUTHORIZED", message: "Not signed in", retryable: false, requestID: nil
    )

    // MARK: Transport

    private func execute(_ request: APIRequest, accessToken: String?) async throws -> Data {
        var components = URLComponents(url: baseURL.appending(path: "v1/\(request.path)"), resolvingAgainstBaseURL: false)
        if !request.query.isEmpty {
            components?.queryItems = request.query
        }
        guard let url = components?.url else { throw APIError.invalidResponse }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = request.method.rawValue
        urlRequest.httpBody = request.body
        if let timeout = request.timeout {
            urlRequest.timeoutInterval = timeout
        }
        if request.body != nil {
            urlRequest.setValue(request.contentType, forHTTPHeaderField: "Content-Type")
        }
        if let accessToken {
            urlRequest.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: urlRequest)
        } catch {
            throw APIError.transport
        }
        guard let http = response as? HTTPURLResponse else { throw APIError.transport }
        guard (200..<300).contains(http.statusCode) else {
            throw Self.error(status: http.statusCode, data: data)
        }
        return data
    }

    private static func error(status: Int, data: Data) -> APIError {
        guard let body = try? JSONDecoder().decode(ErrorBody.self, from: data) else {
            return .server(status: status, code: "HTTP_\(status)", message: "", retryable: status >= 500, requestID: nil)
        }
        return .server(
            status: status, code: body.code, message: body.message, retryable: body.retryable, requestID: body.requestId,
            details: body.details?.mapValues(\.text)
        )
    }

    private struct ErrorBody: Decodable {
        let code: String
        let message: String
        let retryable: Bool
        let requestId: String?
        let details: [String: Scalar]?
    }

    /// A `details` value read as text, whatever JSON scalar it is. Nested values are dropped.
    private struct Scalar: Decodable {
        let text: String

        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            if let value = try? container.decode(String.self) {
                text = value
            } else if let value = try? container.decode(Int.self) {
                text = String(value)
            } else if let value = try? container.decode(Double.self) {
                text = String(value)
            } else if let value = try? container.decode(Bool.self) {
                text = String(value)
            } else {
                text = ""
            }
        }
    }

    private struct RefreshRequest: Encodable {
        let refreshToken: String
    }
}

/// `multipart/form-data` body for the recording upload.
struct MultipartForm {
    let boundary = "VocabFlow-\(UUID().uuidString)"
    private(set) var body = Data()

    var contentType: String { "multipart/form-data; boundary=\(boundary)" }

    mutating func addField(name: String, value: String) {
        append("--\(boundary)\r\nContent-Disposition: form-data; name=\"\(name)\"\r\n\r\n\(value)\r\n")
    }

    mutating func addFile(name: String, filename: String, contentType: String, data: Data) {
        append("--\(boundary)\r\nContent-Disposition: form-data; name=\"\(name)\"; filename=\"\(filename)\"\r\n")
        append("Content-Type: \(contentType)\r\n\r\n")
        body.append(data)
        append("\r\n")
    }

    func finished() -> Data {
        var copy = self
        copy.append("--\(boundary)--\r\n")
        return copy.body
    }

    private mutating func append(_ text: String) {
        body.append(Data(text.utf8))
    }
}
