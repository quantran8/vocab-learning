import Foundation

struct VocabularyItem: Codable, Identifiable, Equatable {
    let id: String
    let term: String
    let meaningVi: String
    let example: String
    var acceptedForms: [String] = []

    var allAcceptedForms: [String] { [term] + acceptedForms }
}

extension VocabularyItem {
    private enum CodingKeys: String, CodingKey {
        case id, term, meaningVi, example, acceptedForms
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        term = try container.decode(String.self, forKey: .term)
        meaningVi = try container.decode(String.self, forKey: .meaningVi)
        example = try container.decode(String.self, forKey: .example)
        acceptedForms = try container.decodeIfPresent([String].self, forKey: .acceptedForms) ?? []
    }
}
