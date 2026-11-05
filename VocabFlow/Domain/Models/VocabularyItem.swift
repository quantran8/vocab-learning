import Foundation

struct VocabularyItem: Codable, Identifiable, Equatable {
    let id: String
    let term: String
    let meaningVi: String
    let example: String
    /// `example` in the learner's explanation locale, when the content has one.
    var exampleTranslation: String?
    var acceptedForms: [String] = []
    var definitionEN: String?
    var ipa: String?
    /// Backend values (`noun`, `phrasal_verb`, ...). A word opened from the library can have several.
    var partsOfSpeech: [String] = []
    var syllables: [String] = []
    var stressIndex: Int?
    var intro: IntroductionPresentation?

    var allAcceptedForms: [String] { [term] + acceptedForms }

    /// Nil when the content has no part of speech, so the intro can leave the line out.
    var partOfSpeechLabel: String? {
        partsOfSpeech.isEmpty ? nil : partsOfSpeech.map(Self.localizedPartOfSpeech).joined(separator: " · ")
    }

    private static func localizedPartOfSpeech(_ value: String) -> String {
        switch value {
        case "noun": String(localized: "noun", bundle: .appLanguage)
        case "verb": String(localized: "verb", bundle: .appLanguage)
        case "adjective": String(localized: "adjective", bundle: .appLanguage)
        case "adverb": String(localized: "adverb", bundle: .appLanguage)
        case "pronoun": String(localized: "pronoun", bundle: .appLanguage)
        case "preposition": String(localized: "preposition", bundle: .appLanguage)
        case "conjunction": String(localized: "conjunction", bundle: .appLanguage)
        case "interjection": String(localized: "interjection", bundle: .appLanguage)
        case "phrasal_verb": String(localized: "phrasal verb", bundle: .appLanguage)
        // A value added on the backend still shows, just untranslated.
        default: value.replacingOccurrences(of: "_", with: " ")
        }
    }

    /// Content-authored intro recipe. Words without one get a recipe picked from the spelling,
    /// so words vary but a given word always opens the same way (String.hashValue is seeded per launch).
    var introPresentation: IntroductionPresentation {
        if let intro { return intro.resolved(for: term) }
        let pool = IntroductionTemplateID.allCases.filter { $0 != .chunkMerge }
        let pick = term.unicodeScalars.reduce(0) { ($0 &* 31 &+ Int($1.value)) & 0x7fffffff }
        return IntroductionPresentation(templateID: pool[pick % pool.count])
    }
}

extension VocabularyItem {
    private enum CodingKeys: String, CodingKey {
        case id, term, meaningVi, example, exampleTranslation, acceptedForms, definitionEN, ipa, partsOfSpeech, syllables, stressIndex, intro
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        term = try container.decode(String.self, forKey: .term)
        meaningVi = try container.decode(String.self, forKey: .meaningVi)
        example = try container.decode(String.self, forKey: .example)
        exampleTranslation = try container.decodeIfPresent(String.self, forKey: .exampleTranslation)
        acceptedForms = try container.decodeIfPresent([String].self, forKey: .acceptedForms) ?? []
        definitionEN = try container.decodeIfPresent(String.self, forKey: .definitionEN)
        ipa = try container.decodeIfPresent(String.self, forKey: .ipa)
        partsOfSpeech = try container.decodeIfPresent([String].self, forKey: .partsOfSpeech) ?? []
        syllables = try container.decodeIfPresent([String].self, forKey: .syllables) ?? []
        stressIndex = try container.decodeIfPresent(Int.self, forKey: .stressIndex)
        intro = try container.decodeIfPresent(IntroductionPresentation.self, forKey: .intro)
    }
}
