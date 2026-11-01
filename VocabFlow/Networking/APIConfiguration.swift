import Foundation

/// Where the backend lives. Override per scheme with the `VOCABFLOW_API_URL` environment variable.
enum APIConfiguration {
    /// The backend's default local port. Simulator only; a device needs a reachable host.
    private static let localURL = "http://127.0.0.1:3000"

    static var baseURL: URL {
        let value = ProcessInfo.processInfo.environment["VOCABFLOW_API_URL"] ?? localURL
        guard let url = URL(string: value) else { fatalError("Invalid API URL: \(value)") }
        return url
    }
}
