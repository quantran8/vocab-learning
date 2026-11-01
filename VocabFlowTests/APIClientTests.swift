import XCTest
@testable import VocabFlow

/// Answers requests from a queue and records them.
final class StubURLProtocol: URLProtocol {
    nonisolated(unsafe) static var responses: [(status: Int, body: String)] = []
    nonisolated(unsafe) static var requests: [URLRequest] = []

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func stopLoading() {}

    override func startLoading() {
        Self.requests.append(request)
        guard !Self.responses.isEmpty else {
            client?.urlProtocol(self, didFailWithError: URLError(.notConnectedToInternet))
            return
        }
        let next = Self.responses.removeFirst()
        let response = HTTPURLResponse(url: request.url!, statusCode: next.status, httpVersion: nil, headerFields: nil)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(next.body.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }
}

final class APIClientTests: XCTestCase {
    private static let refreshed = #"{"accessToken":"new","refreshToken":"r2","expiresIn":3600,"user":{"id":"u","email":null}}"#
    private static let home = #"{"dueCount":1,"checkpointAvailable":0,"checkpointSessionsDone":3,"checkpointSessionsRequired":7,"learnedTotal":2}"#
    private static let unauthorized = #"{"code":"UNAUTHORIZED","message":"no","retryable":false,"requestId":"q"}"#

    private var tokens: InMemoryTokenStore!

    override func setUp() {
        StubURLProtocol.responses = []
        StubURLProtocol.requests = []
        tokens = InMemoryTokenStore(tokens: AuthTokens(accessToken: "old", refreshToken: "r1", expiresAt: .now.addingTimeInterval(3600)))
    }

    private func makeClient() -> APIClient {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]
        return APIClient(
            baseURL: URL(string: "https://api.example.com")!,
            tokens: tokens,
            session: URLSession(configuration: configuration),
            pause: { _ in }
        )
    }

    private var homeRequest: APIRequest { APIRequest(method: .get, path: "me/learn-home") }

    func testSendsBearerTokenUnderV1() async throws {
        StubURLProtocol.responses = [(200, Self.home)]
        let _: LearnHome = try await makeClient().send(homeRequest)
        let request = try XCTUnwrap(StubURLProtocol.requests.first)
        XCTAssertEqual(request.url?.absoluteString, "https://api.example.com/v1/me/learn-home")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer old")
    }

    func testRefreshesOnceAndRetriesAfter401() async throws {
        StubURLProtocol.responses = [(401, Self.unauthorized), (200, Self.refreshed), (200, Self.home)]
        let home: LearnHome = try await makeClient().send(homeRequest)
        XCTAssertEqual(home.dueCount, 1)
        XCTAssertEqual(StubURLProtocol.requests.last?.value(forHTTPHeaderField: "Authorization"), "Bearer new")
        XCTAssertEqual(tokens.load()?.refreshToken, "r2", "Refresh tokens are single use")
    }

    func testRejectedRefreshEndsTheSession() async {
        StubURLProtocol.responses = [(401, Self.unauthorized), (401, Self.unauthorized)]
        let client = makeClient()
        let ended = expectation(description: "session ended")
        await client.setSessionEndedHandler { ended.fulfill() }
        do {
            let _: LearnHome = try await client.send(homeRequest)
            XCTFail("Expected a failure")
        } catch {
            XCTAssertEqual((error as? APIError)?.status, 401)
        }
        await fulfillment(of: [ended], timeout: 1)
        XCTAssertNil(tokens.load())
    }

    func testRefreshOutageKeepsTheSession() async {
        StubURLProtocol.responses = [(401, Self.unauthorized), (503, #"{"code":"AUTH_PROVIDER_UNAVAILABLE","message":"x","retryable":true,"requestId":"q"}"#)]
        do {
            let _: LearnHome = try await makeClient().send(homeRequest)
            XCTFail("Expected a failure")
        } catch {
            XCTAssertEqual((error as? APIError)?.code, "AUTH_PROVIDER_UNAVAILABLE")
        }
        XCTAssertEqual(tokens.load()?.refreshToken, "r1")
    }

    func testExpiringTokenIsRefreshedUpFront() async throws {
        tokens.save(AuthTokens(accessToken: "old", refreshToken: "r1", expiresAt: .now.addingTimeInterval(5)))
        StubURLProtocol.responses = [(200, Self.refreshed), (200, Self.home)]
        let _: LearnHome = try await makeClient().send(homeRequest)
        XCTAssertEqual(StubURLProtocol.requests.count, 2)
        XCTAssertTrue(StubURLProtocol.requests[0].url?.path.hasSuffix("auth/refresh") == true)
    }

    func testConcurrent401sShareOneRefresh() async throws {
        tokens.save(AuthTokens(accessToken: "old", refreshToken: "r1", expiresAt: .now.addingTimeInterval(5)))
        StubURLProtocol.responses = [(200, Self.refreshed), (200, Self.home), (200, Self.home)]
        let client = makeClient()
        async let first: LearnHome = client.send(homeRequest)
        async let second: LearnHome = client.send(homeRequest)
        _ = try await (first, second)
        let refreshes = StubURLProtocol.requests.filter { $0.url?.path.hasSuffix("auth/refresh") == true }
        XCTAssertEqual(refreshes.count, 1)
    }

    func testRetryableFailureBacksOffWhenAllowed() async throws {
        StubURLProtocol.responses = [(500, #"{"code":"INTERNAL_ERROR","message":"x","retryable":true,"requestId":"q"}"#), (200, Self.home)]
        var request = homeRequest
        request.retries = 1
        let _: LearnHome = try await makeClient().send(request)
        XCTAssertEqual(StubURLProtocol.requests.count, 2)
    }

    func testErrorBodyIsDecoded() async {
        StubURLProtocol.responses = [(409, #"{"code":"SESSION_STALE","message":"m","retryable":false,"requestId":"q"}"#)]
        do {
            let _: LearnHome = try await makeClient().send(homeRequest)
            XCTFail("Expected a failure")
        } catch {
            XCTAssertEqual(error as? APIError, .server(status: 409, code: "SESSION_STALE", message: "m", retryable: false, requestID: "q"))
        }
    }

    func testMultipartBodyHasBothParts() {
        var form = MultipartForm()
        form.addField(name: "taskId", value: "t1")
        form.addFile(name: "audio", filename: "a.wav", contentType: "audio/wav", data: Data("RIFF".utf8))
        let body = String(decoding: form.finished(), as: UTF8.self)
        XCTAssertTrue(body.contains("name=\"taskId\"\r\n\r\nt1\r\n"))
        XCTAssertTrue(body.contains("name=\"audio\"; filename=\"a.wav\"\r\nContent-Type: audio/wav\r\n\r\nRIFF\r\n"))
        XCTAssertTrue(body.hasSuffix("--\(form.boundary)--\r\n"))
    }
}
