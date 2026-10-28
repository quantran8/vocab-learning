import Foundation

/// Pure answer rules for Practice Lab templates. Shares normalization with the core session.
enum TemplateEvaluator {
    static func isCorrect(choiceID: String, for exercise: TemplateExercise) -> Bool {
        exercise.acceptedChoiceID == choiceID
    }

    static func acceptedResponses(for exercise: TemplateExercise, word: VocabularyItem) -> [String] {
        exercise.acceptedResponses ?? word.allAcceptedForms
    }

    static func isCorrect(typed text: String, for exercise: TemplateExercise, word: VocabularyItem) -> Bool {
        let input = AnswerEvaluator.normalize(text)
        guard !input.isEmpty else { return false }
        return acceptedResponses(for: exercise, word: word).contains { AnswerEvaluator.normalize($0) == input }
    }

    static func isMatch(wordID: String, glossWordID: String) -> Bool {
        wordID == glossWordID
    }

    static func isWrongCharacter(index: Int, in exercise: TemplateExercise) -> Bool {
        exercise.wrongCharacterIndex == index
    }

    static func repaired(_ exercise: TemplateExercise, index: Int, replacement: String) -> String? {
        var letters = exercise.misspellingLetters
        guard letters.indices.contains(index), replacement.count == 1, let character = replacement.first else { return nil }
        letters[index] = character
        return String(letters)
    }

    /// Accepts a repair only when the resulting spelling is the target word.
    static func isCorrectRepair(_ replacement: String, for exercise: TemplateExercise, word: VocabularyItem) -> Bool {
        guard let index = exercise.wrongCharacterIndex,
              let result = repaired(exercise, index: index, replacement: replacement)
        else { return false }
        return AnswerEvaluator.normalize(result) == AnswerEvaluator.normalize(word.term)
    }

    static func isStressed(syllableIndex: Int, in word: VocabularyItem) -> Bool {
        word.stressIndex == syllableIndex && word.syllables.indices.contains(syllableIndex)
    }

    static func hints(for exercise: TemplateExercise, word: VocabularyItem) -> [String] {
        if let sequence = exercise.hintSequence, !sequence.isEmpty { return sequence }
        return (1...HintSequence.maxHints).compactMap { HintSequence.hint(for: word.term, level: $0) }
    }
}
