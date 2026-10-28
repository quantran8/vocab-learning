import Foundation

enum DemoContentError: Error {
    case missingResource
    case invalid([ContentIssue])
    case invalidTemplates([TemplateContentIssue])
}

struct DemoContentRepository {
    var bundle: Bundle = .main
    var resourceName = "demo_words"
    var templatesResourceName = "demo_templates"

    func load() throws -> DemoContent {
        try Self.decode(Data(contentsOf: url(resourceName)))
    }

    func loadTemplates(words: [VocabularyItem]) throws -> TemplateLibrary {
        try Self.decodeTemplates(Data(contentsOf: url(templatesResourceName)), words: words)
    }

    static func decode(_ data: Data) throws -> DemoContent {
        let raw = try JSONDecoder().decode(DemoContent.self, from: data)
        let issues = ContentValidator.validate(raw)
        guard issues.isEmpty else {
            throw DemoContentError.invalid(issues)
        }
        return raw.withShuffledOptions(seed: raw.seed ?? DemoSeed.defaultSeed)
    }

    static func decodeTemplates(_ data: Data, words: [VocabularyItem]) throws -> TemplateLibrary {
        let raw = try JSONDecoder().decode(TemplateLibrary.self, from: data)
        let issues = TemplateContentValidator.validate(raw, words: words)
        guard issues.isEmpty else {
            throw DemoContentError.invalidTemplates(issues)
        }
        return raw.withShuffledChoices(seed: raw.seed ?? DemoSeed.defaultSeed)
    }

    func loadOrFail() -> DemoContent {
        do {
            return try load()
        } catch {
            fatalError("Demo content failed to load: \(error)")
        }
    }

    func loadTemplatesOrFail(words: [VocabularyItem]) -> TemplateLibrary {
        do {
            return try loadTemplates(words: words)
        } catch {
            fatalError("Template content failed to load: \(error)")
        }
    }

    private func url(_ name: String) throws -> URL {
        guard let url = bundle.url(forResource: name, withExtension: "json") else {
            throw DemoContentError.missingResource
        }
        return url
    }
}
