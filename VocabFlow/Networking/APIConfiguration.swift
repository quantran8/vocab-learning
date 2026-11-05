import Foundation

/// Where the backend lives. Override per scheme with the `VOCABFLOW_API_URL` environment variable.
enum APIConfiguration {
    #if targetEnvironment(simulator)
    private static let defaultURL = "http://127.0.0.1:3000"
    #else
    private static let defaultURL = "https://moneytogether.dpdns.org/service/vocab/"
    #endif

    static var baseURL: URL {
        let value = ProcessInfo.processInfo.environment["VOCABFLOW_API_URL"] ?? defaultURL
        guard let url = URL(string: value) else { fatalError("Invalid API URL: \(value)") }
        return url
    }
}
