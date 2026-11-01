import Foundation

// MARK: - Lookup

/// The word to highlight in a sentence. Offsets count UTF-16 code units, as the backend does;
/// `end` is exclusive.
struct TargetLocator: Codable, Equatable {
    let start: Int
    let end: Int
}

extension TargetLocator {
    /// First case-insensitive match, which is how the backend places a target.
    init?(locating target: String, in sentence: String) {
        let needle = target.trimmed
        guard !needle.isEmpty else { return nil }
        let match = (sentence as NSString).range(of: needle, options: .caseInsensitive)
        guard match.location != NSNotFound else { return nil }
        self.init(start: match.location, end: NSMaxRange(match))
    }

    /// Nil when the locator falls outside the sentence.
    func nsRange(in sentence: String) -> NSRange? {
        guard start >= 0, start < end, end <= sentence.utf16.count else { return nil }
        return NSRange(location: start, length: end - start)
    }

    func substring(of sentence: String) -> String? {
        nsRange(in: sentence).flatMap { Range($0, in: sentence) }.map { String(sentence[$0]) }
    }

    /// One locator per word, in reading order, without the punctuation between them.
    static func words(in sentence: String) -> [TargetLocator] {
        var words: [TargetLocator] = []
        sentence.enumerateSubstrings(in: sentence.startIndex..., options: [.byWords, .substringNotRequired]) { _, range, _, _ in
            let span = NSRange(range, in: sentence)
            words.append(TargetLocator(start: span.location, end: NSMaxRange(span)))
        }
        return words
    }

    func contains(_ other: TargetLocator) -> Bool {
        start <= other.start && other.end <= end
    }
}

struct CustomWordExample: Codable, Equatable {
    let text: String
    let translation: String
    let targetLocator: TargetLocator
}

/// `POST /custom-words/lookup` body; a nil context is omitted.
struct CustomWordQuery: Encodable, Equatable {
    let text: String
    var context: String?
}

struct ExistingMeaning: Decodable, Equatable, Identifiable {
    enum Status: String, Decodable {
        case available, unavailable
        case translationDraft = "translation_draft"
    }

    let meaningId: String
    let status: Status
    let partOfSpeech: String
    let inRoadmap: Bool
    /// Only on `translationDraft`.
    let draftId: String?
    /// Absent on `unavailable`.
    let meaningText: String?
    let definitionText: String?
    let examples: [CustomWordExample]?

    var id: String { meaningId }

    /// Nil when this meaning can't be added.
    var addition: CustomWordAddition? {
        switch status {
        case .available: .meaning(meaningId)
        case .translationDraft: draftId.map { .translation(draftID: $0) }
        case .unavailable: nil
        }
    }
}

struct ExistingWord: Decodable, Equatable {
    let wordId: String
    let lemma: String
    let meanings: [ExistingMeaning]
}

struct DraftSense: Decodable, Equatable {
    let partOfSpeech: String
    let ipa: String?
    let cefrLevel: String?
    let meaningText: String
    let definitionText: String
    let examples: [CustomWordExample]
}

struct WordDraft: Decodable, Equatable {
    let draftId: String
    let lemma: String
    let senses: [DraftSense]
}

enum CustomWordLookup: Decodable, Equatable {
    case existing(ExistingWord)
    case draft(WordDraft)
    /// As `draft`, but the meaning stays private to this learner.
    case newMeaningDraft(WordDraft)
    case invalid

    private enum CodingKeys: String, CodingKey {
        case result
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        switch try container.decode(String.self, forKey: .result) {
        case "existing": self = .existing(try ExistingWord(from: decoder))
        case "draft": self = .draft(try WordDraft(from: decoder))
        case "new_meaning_draft": self = .newMeaningDraft(try WordDraft(from: decoder))
        case "invalid": self = .invalid
        default:
            throw DecodingError.dataCorruptedError(forKey: .result, in: container, debugDescription: "Unknown lookup result")
        }
    }
}

// MARK: - Adding and editing

/// Changes to a learner's own copy. The backend merges by field, so nil fields are omitted and
/// keep what they had; `examples` replaces the whole list.
struct CustomWordEdits: Codable, Equatable {
    var meaningText: String?
    var definitionText: String?
    var examples: [CustomWordExample]?
}

/// `POST /custom-words` body. The backend rejects any other field, so the factories below are
/// the only ways to build one.
struct CustomWordAddition: Encodable, Equatable {
    private(set) var meaningId: String?
    private(set) var draftId: String?
    private(set) var senseIndex: Int?
    var edits: CustomWordEdits?

    static func meaning(_ id: String) -> CustomWordAddition {
        CustomWordAddition(meaningId: id)
    }

    static func translation(draftID: String) -> CustomWordAddition {
        CustomWordAddition(draftId: draftID)
    }

    static func draft(_ id: String, senseIndex: Int, edits: CustomWordEdits?) -> CustomWordAddition {
        CustomWordAddition(draftId: id, senseIndex: senseIndex, edits: edits)
    }
}

struct CustomWordAdded: Decodable, Equatable {
    let meaningId: String
    /// False when it was already on the roadmap, which still counts as success.
    let added: Bool
}

// MARK: - The learner's list

struct CustomWord: Decodable, Equatable, Identifiable {
    let meaningId: String
    let wordId: String
    let lemma: String
    let partOfSpeech: String
    /// Nil while `translationPending` or `recalled`.
    let meaningText: String?
    let definitionText: String?
    let examples: [CustomWordExample]?
    let audioUrl: URL?
    let overridden: Bool
    let translationPending: Bool
    let recalled: Bool

    var id: String { meaningId }
    var isEditable: Bool { !translationPending && !recalled && meaningText != nil && definitionText != nil }
}

// MARK: - Input rules

/// Mirrors the backend's validation, so a bad word never costs a round trip.
enum CustomWordInput {
    enum Issue: Equatable {
        case empty, tooLong, invalidCharacters
    }

    static let maxTextLength = 64
    static let maxContextLength = 200
    static let maxFieldLength = 500
    static let maxExamples = 3

    private static let punctuation: Set<Character> = [" ", "-", "'", "‘", "’"]

    static func issue(in text: String) -> Issue? {
        let word = text.trimmed
        guard let first = word.first else { return .empty }
        guard word.utf16.count <= maxTextLength else { return .tooLong }
        guard first.isLetter, word.allSatisfy({ $0.isLetter || punctuation.contains($0) }) else { return .invalidCharacters }
        return nil
    }

    static func isValidField(_ text: String) -> Bool {
        (1...maxFieldLength).contains(text.trimmed.utf16.count)
    }
}

/// Editable copy of a word's text. Turns what changed into `edits`, and keeps every example's
/// highlight valid while its sentence is rewritten.
struct CustomWordEditDraft: Equatable {
    struct Example: Equatable, Identifiable {
        let id: Int
        var text: String
        var translation: String
        fileprivate let original: CustomWordExample
        /// The learner's own highlight, valid only for the sentence it was picked in.
        fileprivate var picked: Pick?

        fileprivate struct Pick: Equatable {
            let sentence: String
            let locator: TargetLocator
        }

        fileprivate init(id: Int, original: CustomWordExample) {
            self.id = id
            self.original = original
            text = original.text
            translation = original.translation
        }

        var isUnchanged: Bool {
            !isRewritten && translation.trimmed == original.translation
        }

        var isRewritten: Bool { text.trimmed != original.text }
    }

    let lemma: String
    var meaningText: String
    var definitionText: String
    var examples: [Example]

    private let originalMeaning: String
    private let originalDefinition: String

    init(lemma: String, sense: DraftSense) {
        self.init(lemma: lemma, meaning: sense.meaningText, definition: sense.definitionText, examples: sense.examples)
    }

    init(lemma: String, meaning: ExistingMeaning) {
        self.init(lemma: lemma, meaning: meaning.meaningText, definition: meaning.definitionText, examples: meaning.examples)
    }

    init(word: CustomWord) {
        self.init(lemma: word.lemma, meaning: word.meaningText, definition: word.definitionText, examples: word.examples)
    }

    private init(lemma: String, meaning: String?, definition: String?, examples: [CustomWordExample]?) {
        self.lemma = lemma
        meaningText = meaning ?? ""
        definitionText = definition ?? ""
        self.examples = (examples ?? []).prefix(CustomWordInput.maxExamples).enumerated().map {
            Example(id: $0.offset, original: $0.element)
        }
        originalMeaning = meaningText
        originalDefinition = definitionText
    }

    /// An untouched sentence keeps its locator: the target may not be the first match.
    /// A rewritten one uses the learner's pick, then the old target, then the dictionary form.
    func locator(for example: Example) -> TargetLocator? {
        guard example.isRewritten else { return example.original.targetLocator }
        let sentence = example.text.trimmed
        if let picked = example.picked, picked.sentence == sentence { return picked.locator }
        let target = example.original.targetLocator.substring(of: example.original.text) ?? lemma
        return TargetLocator(locating: target, in: sentence) ?? TargetLocator(locating: lemma, in: sentence)
    }

    /// Tapping a word highlights it; tapping another next extends the highlight up to that word.
    mutating func pick(_ word: TargetLocator, inExample id: Example.ID) {
        guard let index = examples.firstIndex(where: { $0.id == id }) else { return }
        let sentence = examples[index].text.trimmed
        var locator = word
        if let current = self.locator(for: examples[index]), current != word,
           TargetLocator.words(in: sentence).contains(current) {
            locator = TargetLocator(start: min(current.start, word.start), end: max(current.end, word.end))
        }
        examples[index].picked = Example.Pick(sentence: sentence, locator: locator)
    }

    var isValid: Bool {
        CustomWordInput.isValidField(meaningText)
            && CustomWordInput.isValidField(definitionText)
            && examples.allSatisfy {
                CustomWordInput.isValidField($0.text) && CustomWordInput.isValidField($0.translation) && locator(for: $0) != nil
            }
    }

    /// What to send, or nil when nothing changed: `edits` goes out only for a real edit.
    var edits: CustomWordEdits? {
        let meaning = meaningText.trimmed
        let definition = definitionText.trimmed
        let meaningChanged = meaning != originalMeaning
        let definitionChanged = definition != originalDefinition
        let examplesChanged = examples.contains { !$0.isUnchanged }
        guard meaningChanged || definitionChanged || examplesChanged else { return nil }
        return CustomWordEdits(
            meaningText: meaningChanged ? meaning : nil,
            definitionText: definitionChanged ? definition : nil,
            examples: examplesChanged ? examples.compactMap(payload) : nil
        )
    }

    private func payload(_ example: Example) -> CustomWordExample? {
        locator(for: example).map {
            CustomWordExample(text: example.text.trimmed, translation: example.translation.trimmed, targetLocator: $0)
        }
    }
}

extension String {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
}
