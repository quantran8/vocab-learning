import Foundation

enum DemoContentError: Error {
    case missingResource
    case invalid([ContentIssue])
}

struct DemoContentRepository {
    var bundle: Bundle = .main
    var resourceName = "demo_words"
    var labResourceName = "practice_lab"

    func load() throws -> DemoContent {
        try Self.decode(Data(contentsOf: url(resourceName)))
    }

    func loadLab() throws -> LabLibrary {
        try Self.decodeLab(Data(contentsOf: url(labResourceName)))
    }

    static func decode(_ data: Data) throws -> DemoContent {
        let raw = try JSONDecoder().decode(DemoContent.self, from: data)
        let issues = ContentValidator.validate(raw)
        guard issues.isEmpty else {
            throw DemoContentError.invalid(issues)
        }
        return raw.withShuffledOptions(seed: raw.seed ?? DemoSeed.defaultSeed)
    }

    static func decodeLab(_ data: Data) throws -> LabLibrary {
        let library = try JSONDecoder().decode(LabLibrary.self, from: data)
        try library.validate()
        return library
    }

    func loadOrFail() -> DemoContent {
        do {
            return try load()
        } catch {
            fatalError("Demo content failed to load: \(error)")
        }
    }

    func loadLabOrFail() -> LabLibrary {
        do {
            return try loadLab()
        } catch {
            fatalError("Practice Lab content failed to load: \(error)")
        }
    }

    private func url(_ name: String) throws -> URL {
        guard let url = bundle.url(forResource: name, withExtension: "json") else {
            throw DemoContentError.missingResource
        }
        return url
    }
}
