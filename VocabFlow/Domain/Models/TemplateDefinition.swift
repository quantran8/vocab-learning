import Foundation

enum TemplateCategory: String, Codable, CaseIterable, Identifiable {
    case classic, creative, skill

    var id: String { rawValue }
}

/// The reusable interaction/evaluation patterns playable in Practice Lab.
/// Fill the Blank and Phrase Snap are content variants of Word Stack (same board and evaluator).
enum TemplateKind: String, Codable, CaseIterable, Identifiable {
    case select, match, stack, audioSelect, typing
    case surgery, split
    case trace, echo

    var id: String { rawValue }

    var category: TemplateCategory {
        switch self {
        case .select, .match, .stack, .audioSelect, .typing: .classic
        case .surgery, .split: .creative
        case .trace, .echo: .skill
        }
    }

    var allowedVariants: Set<TemplateVariant> {
        switch self {
        case .select: [.gloss, .meaningClash]
        case .stack: [.sentence, .fillBlank, .phrase]
        default: []
        }
    }

    /// Templates whose primary cue is spoken audio; they must offer a non-audio fallback.
    var usesAudio: Bool {
        switch self {
        case .audioSelect, .split, .trace, .echo: true
        default: false
        }
    }
}

/// Content framing inside one template. Variants reuse the same mechanic and evaluator.
enum TemplateVariant: String, Codable {
    // Select Meaning
    case gloss, meaningClash
    // Word Stack
    case sentence, fillBlank, phrase
}

struct TemplateExercise: Codable, Identifiable, Equatable {
    let id: String
    let wordID: String
    let prompt: String
    var variant: TemplateVariant?
    var context: String?
    var choices: [WordOption]?
    var acceptedChoiceID: String?
    var explanations: [String: String]?
    var pairWordIDs: [String]?
    var acceptedResponses: [String]?
    var hintSequence: [String]?
    var audioText: String?
    var misspelling: String?
    var wrongCharacterIndex: Int?
    var replacementChoices: [String]?
    var replacementCharacter: String?
    let feedback: String

    func choice(id: String) -> WordOption? {
        choices?.first { $0.id == id }
    }

    /// Grapheme-aware letters of the misspelling (Character, not UTF-16 units).
    var misspellingLetters: [Character] {
        Array(misspelling ?? "")
    }
}

struct TemplateDefinition: Codable, Identifiable, Equatable {
    let id: TemplateKind
    let title: String
    let action: String
    let systemImage: String
    var exercises: [TemplateExercise]

    var category: TemplateCategory { id.category }
}

struct TemplateLibrary: Codable, Equatable {
    var seed: UInt64?
    var templates: [TemplateDefinition]

    func template(_ kind: TemplateKind) -> TemplateDefinition? {
        templates.first { $0.id == kind }
    }

    func withShuffledChoices(seed: UInt64) -> TemplateLibrary {
        var copy = self
        copy.templates = templates.enumerated().map { templateIndex, template in
            var shuffled = template
            shuffled.exercises = template.exercises.enumerated().map { exerciseIndex, exercise in
                var exercise = exercise
                if let choices = exercise.choices {
                    let salt = UInt64(templateIndex * 31 + exerciseIndex)
                    exercise.choices = DemoSeed.shuffled(choices, seed: seed &+ salt)
                }
                return exercise
            }
            return shuffled
        }
        return copy
    }
}
