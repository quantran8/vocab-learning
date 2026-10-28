import Foundation

enum TemplateContentIssue: Equatable {
    case duplicateID(kind: String, id: String)
    case emptyText(field: String, id: String)
    case noExercises(template: TemplateKind)
    case unknownWordID(exerciseID: String, wordID: String)
    case choiceCount(exerciseID: String, count: Int)
    case invalidAcceptedChoice(exerciseID: String)
    case missingBlank(exerciseID: String)
    case pairCount(exerciseID: String, count: Int)
    case missingAcceptedResponses(exerciseID: String)
    case invalidMisspelling(exerciseID: String)
    case invalidReplacement(exerciseID: String)
    case invalidSyllables(wordID: String)
    case invalidStressIndex(wordID: String)
    case unexpectedVariant(exerciseID: String)
}

enum TemplateContentValidator {
    static func validate(_ library: TemplateLibrary, words: [VocabularyItem]) -> [TemplateContentIssue] {
        var issues: [TemplateContentIssue] = []
        let wordsByID = Dictionary(words.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })

        issues += duplicates(library.templates.map(\.id.rawValue), kind: "template")
        issues += duplicates(library.templates.flatMap { $0.exercises.map(\.id) }, kind: "exercise")

        for template in library.templates {
            issues += empty(["title": template.title, "action": template.action, "systemImage": template.systemImage], id: template.id.rawValue)
            if template.exercises.isEmpty {
                issues.append(.noExercises(template: template.id))
            }
            for exercise in template.exercises {
                issues += validate(exercise, kind: template.id, wordsByID: wordsByID)
            }
        }
        return issues
    }

    private static func validate(_ exercise: TemplateExercise, kind: TemplateKind, wordsByID: [String: VocabularyItem]) -> [TemplateContentIssue] {
        var issues = empty(["prompt": exercise.prompt, "feedback": exercise.feedback], id: exercise.id)
        guard let word = wordsByID[exercise.wordID] else {
            return issues + [.unknownWordID(exerciseID: exercise.id, wordID: exercise.wordID)]
        }
        if let variant = exercise.variant, !kind.allowedVariants.contains(variant) {
            issues.append(.unexpectedVariant(exerciseID: exercise.id))
        }

        switch kind {
        case .select, .audioSelect, .stack:
            let choices = exercise.choices ?? []
            if choices.count < 2 {
                issues.append(.choiceCount(exerciseID: exercise.id, count: choices.count))
            }
            issues += duplicates(choices.map(\.id), kind: "choice")
            for choice in choices {
                issues += empty(["choice.text": choice.text], id: exercise.id)
            }
            if exercise.acceptedChoiceID.flatMap(exercise.choice(id:)) == nil {
                issues.append(.invalidAcceptedChoice(exerciseID: exercise.id))
            }
            if kind == .stack, !exercise.prompt.contains(BuildChallenge.blank) {
                issues.append(.missingBlank(exerciseID: exercise.id))
            }

        case .match:
            let ids = exercise.pairWordIDs ?? []
            if ids.count < 2 {
                issues.append(.pairCount(exerciseID: exercise.id, count: ids.count))
            }
            issues += duplicates(ids, kind: "pair")
            for id in ids where wordsByID[id] == nil {
                issues.append(.unknownWordID(exerciseID: exercise.id, wordID: id))
            }

        case .typing, .trace, .echo:
            break

        case .surgery:
            let letters = exercise.misspellingLetters
            if letters.isEmpty || exercise.wrongCharacterIndex.map(letters.indices.contains) != true
                || AnswerEvaluator.normalize(String(letters)) == AnswerEvaluator.normalize(word.term) {
                issues.append(.invalidMisspelling(exerciseID: exercise.id))
            }
            let replacements = exercise.replacementChoices ?? []
            let isValidRepair = exercise.replacementCharacter.map { replacement in
                replacements.contains(replacement)
                    && replacements.allSatisfy { $0.count == 1 }
                    && TemplateEvaluator.isCorrectRepair(replacement, for: exercise, word: word)
            } ?? false
            if !isValidRepair {
                issues.append(.invalidReplacement(exerciseID: exercise.id))
            }

        case .split:
            if word.syllables.isEmpty || word.syllables.joined().lowercased() != word.term.lowercased() {
                issues.append(.invalidSyllables(wordID: word.id))
            }
            if word.stressIndex.map(word.syllables.indices.contains) != true {
                issues.append(.invalidStressIndex(wordID: word.id))
            }
        }
        return issues
    }

    private static func duplicates(_ ids: [String], kind: String) -> [TemplateContentIssue] {
        var seen = Set<String>()
        var reported = Set<String>()
        var issues: [TemplateContentIssue] = []
        for id in ids where !seen.insert(id).inserted && reported.insert(id).inserted {
            issues.append(.duplicateID(kind: kind, id: id))
        }
        return issues
    }

    private static func empty(_ fields: [String: String], id: String) -> [TemplateContentIssue] {
        fields
            .filter { $0.value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .keys.sorted()
            .map { .emptyText(field: $0, id: id) }
    }
}
