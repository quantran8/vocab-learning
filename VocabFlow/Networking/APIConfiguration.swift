import Foundation

/// Where the backend lives. Override per scheme with the `VOCABFLOW_API_URL` environment variable.
enum APIConfiguration {
    /// The backend's default local port. A device reaches the dev Mac over Bonjour
    /// (`scutil --get LocalHostName`), allowed by `NSAllowsLocalNetworking` in `VocabFlow-Info.plist`.
    #if targetEnvironment(simulator)
    private static let localURL = "http://127.0.0.1:3000"
    #else
    private static let localURL = "http://quans-MacBook-Pro.local:3000"
    #endif

    static var baseURL: URL {
        let value = ProcessInfo.processInfo.environment["VOCABFLOW_API_URL"] ?? localURL
        guard let url = URL(string: value) else { fatalError("Invalid API URL: \(value)") }
        return url
    }
}
