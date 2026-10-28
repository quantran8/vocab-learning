import Foundation

struct VocabularyItem: Codable, Identifiable, Equatable {
    let id: String
    let term: String
    let meaningVi: String
    let example: String
    var acceptedForms: [String] = []
    var definitionEN: String?
    var ipa: String?
    var syllables: [String] = []
    var stressIndex: Int?
    var intro: IntroductionPresentation?

    var allAcceptedForms: [String] { [term] + acceptedForms }

    /// Stable, content-authored intro recipe; defaults to Letter Cascade.
    var introPresentation: IntroductionPresentation {
        (intro ?? IntroductionPresentation(templateID: .letterCascade)).resolved(for: term)
    }
}

extension VocabularyItem {
    private enum CodingKeys: String, CodingKey {
        case id, term, meaningVi, example, acceptedForms, definitionEN, ipa, syllables, stressIndex, intro
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        term = try container.decode(String.self, forKey: .term)
        meaningVi = try container.decode(String.self, forKey: .meaningVi)
        example = try container.decode(String.self, forKey: .example)
        acceptedForms = try container.decodeIfPresent([String].self, forKey: .acceptedForms) ?? []
        definitionEN = try container.decodeIfPresent(String.self, forKey: .definitionEN)
        ipa = try container.decodeIfPresent(String.self, forKey: .ipa)
        syllables = try container.decodeIfPresent([String].self, forKey: .syllables) ?? []
        stressIndex = try container.decodeIfPresent(Int.self, forKey: .stressIndex)
        intro = try container.decodeIfPresent(IntroductionPresentation.self, forKey: .intro)
    }
}
