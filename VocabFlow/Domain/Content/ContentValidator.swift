import Foundation

enum ContentIssue: Equatable {
    case emptyText(field: String, id: String)
    case duplicateID(kind: String, id: String)
    case unknownWordID(referencedBy: String, wordID: String)
    case invalidAcceptedOption(challengeID: String, optionID: String)
    case acceptedOptionCount(challengeID: String, count: Int)
    case optionCount(challengeID: String, count: Int)
    case missingBlank(id: String)
    case wordWithoutBuild(wordID: String)
    case wordWithoutRecall(wordID: String)
    case invalidIntroChunks(wordID: String)
}

enum ContentValidator {
    static let optionsPerChallenge = 3

    static func validate(_ content: DemoContent) -> [ContentIssue] {
        var issues: [ContentIssue] = []
        let wordIDs = Set(content.words.map(\.id))

        issues += duplicates(content.words.map(\.id), kind: "word")
        issues += duplicates(content.buildChallenges.map(\.id), kind: "buildChallenge")
        issues += duplicates(content.recallPrompts.map(\.id), kind: "recallPrompt")

        for word in content.words {
            issues += empty(["id": word.id, "term": word.term, "meaningVi": word.meaningVi, "example": word.example], id: word.id)
            if !content.buildChallenges.contains(where: { $0.wordID == word.id }) {
                issues.append(.wordWithoutBuild(wordID: word.id))
            }
            if !content.recallPrompts.contains(where: { $0.wordID == word.id }) {
                issues.append(.wordWithoutRecall(wordID: word.id))
            }
            if let intro = word.intro,
               intro.templateID == .chunkMerge || intro.introChunks != nil,
               !IntroductionPresentation.areValidChunks(intro.introChunks, for: word.term) {
                issues.append(.invalidIntroChunks(wordID: word.id))
            }
        }

        for challenge in content.buildChallenges {
            issues += empty(["id": challenge.id, "context": challenge.context, "prompt": challenge.prompt], id: challenge.id)
            if !wordIDs.contains(challenge.wordID) {
                issues.append(.unknownWordID(referencedBy: challenge.id, wordID: challenge.wordID))
            }
            if !challenge.prompt.contains(BuildChallenge.blank) {
                issues.append(.missingBlank(id: challenge.id))
            }
            if challenge.options.count != optionsPerChallenge {
                issues.append(.optionCount(challengeID: challenge.id, count: challenge.options.count))
            }
            issues += duplicates(challenge.options.map(\.id), kind: "option")
            for option in challenge.options {
                issues += empty(["option.id": option.id, "option.text": option.text], id: challenge.id)
            }
            if challenge.acceptedOptionIDs.count != 1 {
                issues.append(.acceptedOptionCount(challengeID: challenge.id, count: challenge.acceptedOptionIDs.count))
            }
            for accepted in challenge.acceptedOptionIDs where challenge.option(id: accepted) == nil {
                issues.append(.invalidAcceptedOption(challengeID: challenge.id, optionID: accepted))
            }
        }

        for prompt in content.recallPrompts {
            issues += empty(["id": prompt.id, "sentence": prompt.sentence], id: prompt.id)
            if !wordIDs.contains(prompt.wordID) {
                issues.append(.unknownWordID(referencedBy: prompt.id, wordID: prompt.wordID))
            }
            if !prompt.sentence.contains(BuildChallenge.blank) {
                issues.append(.missingBlank(id: prompt.id))
            }
        }

        return issues
    }

    private static func duplicates(_ ids: [String], kind: String) -> [ContentIssue] {
        var seen = Set<String>()
        var reported = Set<String>()
        var issues: [ContentIssue] = []
        for id in ids where !seen.insert(id).inserted && reported.insert(id).inserted {
            issues.append(.duplicateID(kind: kind, id: id))
        }
        return issues
    }

    private static func empty(_ fields: [String: String], id: String) -> [ContentIssue] {
        fields
            .filter { $0.value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .keys.sorted()
            .map { .emptyText(field: $0, id: id) }
    }
}
