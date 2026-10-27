import Foundation

enum DemoContentError: Error {
    case missingResource
    case invalid([ContentIssue])
}

struct DemoContentRepository {
    var bundle: Bundle = .main
    var resourceName = "demo_words"

    func load() throws -> DemoContent {
        guard let url = bundle.url(forResource: resourceName, withExtension: "json") else {
            throw DemoContentError.missingResource
        }
        return try Self.decode(Data(contentsOf: url))
    }

    static func decode(_ data: Data) throws -> DemoContent {
        let raw = try JSONDecoder().decode(DemoContent.self, from: data)
        let issues = ContentValidator.validate(raw)
        guard issues.isEmpty else {
            throw DemoContentError.invalid(issues)
        }
        return raw.withShuffledOptions(seed: raw.seed ?? DemoSeed.defaultSeed)
    }

    func loadOrFail() -> DemoContent {
        do {
            return try load()
        } catch {
            fatalError("Demo content failed to load: \(error)")
        }
    }
}
