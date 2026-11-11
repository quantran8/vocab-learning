import Foundation

enum PracticeAnswer {
    /// Must stay identical to the backend's `normalizeAnswer`, or instant feedback disagrees with the
    /// commit: NFC, trim, collapse whitespace runs, lowercase. Punctuation and diacritics are kept.
    static func normalize(_ text: String) -> String {
        text.precomposedStringWithCanonicalMapping
            .components(separatedBy: whitespace)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
            .lowercased()
    }

    static func matches(_ text: String, accepted: [String]) -> Bool {
        let input = normalize(text)
        return accepted.contains { normalize($0) == input }
    }

    /// Grapheme clusters of the NFC string; `graphemeIndex` counts in these.
    static func graphemes(_ text: String) -> [String] {
        text.precomposedStringWithCanonicalMapping.map(String.init)
    }

    /// JavaScript's `\s` also matches the byte order mark.
    private static let whitespace = CharacterSet.whitespacesAndNewlines.union(CharacterSet(charactersIn: "\u{FEFF}"))
}

/// The learner's work on one task: replayable events, plus the state the screen renders.
/// Pure and client-side only; the outcome that counts is the backend's, computed at commit.
struct TaskAttempt: Equatable {
    enum Status: Equatable {
        case answering
        /// A wrong answer is on screen, waiting for "Try again" or "Show answer".
        case wrong
        case solved
        case revealed
        /// Recording only: assessed, or reported as unavailable.
        case recorded
        /// Ran out of tries or events on a wrong answer; ends here so commit stays valid.
        /// Adds no event of its own: the backend scores the task incorrect.
        case exhausted
    }

    /// Mirrors the backend's per-task limit; going over rejects the entire commit.
    static let maxEvents = 200
    static let maxValueLength = 200
    static let maxReplacementLength = 32
    static let maxRepairEdits = 64
    static let maxHints = HintSequence.maxHints

    let task: PracticeTask
    /// The first recall of a new word needs a real attempt: a reveal alone rejects the entire commit.
    let requiresSubmission: Bool

    private(set) var events: [TaskEvent] = []
    private(set) var status: Status = .answering
    private(set) var submitCount = 0
    private(set) var hintsUsed = 0
    /// Tile ids currently in the answer row, in order.
    private(set) var placedTileIDs: [Int] = []
    private(set) var matchedLeftIDs: Set<Int> = []
    /// Left items out of tries. They score incorrect and no longer hold up the board.
    private(set) var exhaustedLeftIDs: Set<Int> = []
    private(set) var lastWrongOptionID: Int?
    private(set) var lastWrongPair: PairKey?
    private var missesByLeftID: [Int: Int] = [:]
    private var assessmentCount = 0
    private var passedFirstTake = false
    private var audioDelivery: DeliveryMode = .none

    init(task: PracticeTask, phase: TaskPhase) {
        self.task = task
        let isRecall = task.template == .typing || task.template == .flyReorder
        // A known check must be tried before the answer can be shown.
        requiresSubmission = (phase == .newPractice || phase == .knownCheck) && isRecall
    }

    /// A local display figure, not a score.
    var isRightFirstTime: Bool {
        switch status {
        case .solved: submitCount <= 1 && hintsUsed == 0
        case .recorded: passedFirstTake
        default: false
        }
    }

    var isFinished: Bool {
        switch status {
        case .solved, .revealed, .recorded, .exhausted: true
        case .answering, .wrong: false
        }
    }

    var canReveal: Bool {
        !isFinished && task.template != .recording && (!requiresSubmission || submitCount > 0)
    }

    var canUseHint: Bool {
        !isFinished && status != .wrong && hintsUsed < Self.maxHints && acceptedAnswer != nil && hasRoomForEvent
    }

    /// The answer shown once the task is finished. Never display it before that.
    var acceptedAnswer: String? {
        switch task.body {
        case .typing(let accepted), .reorder(_, let accepted): accepted.first
        default: nil
        }
    }

    var hints: [String] {
        guard let acceptedAnswer else { return [] }
        return (0..<hintsUsed).compactMap { HintSequence.hint(for: acceptedAnswer, level: $0 + 1) }
    }

    var bankTiles: [TaskOption] {
        guard case .reorder(let tiles, _) = task.body else { return [] }
        return tiles.filter { !placedTileIDs.contains($0.id) }
    }

    var placedTiles: [TaskOption] {
        guard case .reorder(let tiles, _) = task.body else { return [] }
        return placedTileIDs.compactMap { id in tiles.first { $0.id == id } }
    }

    var result: TaskResult {
        TaskResult(taskId: task.id, deliveryMode: deliveryMode, events: events)
    }

    /// `audio` only when sound really played. Text prompts send nothing.
    var deliveryMode: DeliveryMode? {
        task.prompt?.isAudio == true ? audioDelivery : nil
    }

    // MARK: Answers. Each returns whether the answer was right; nil means it was ignored.

    @discardableResult
    mutating func submitOption(_ id: Int) -> Bool? {
        guard canAnswer, case .choice(let options, _, let correct) = task.body,
              options.contains(where: { $0.id == id })
        else { return nil }
        lastWrongOptionID = id == correct ? nil : id
        return finishSubmit(.submitOption(id), isCorrect: id == correct)
    }

    @discardableResult
    mutating func submitText(_ text: String) -> Bool? {
        guard canAnswer, case .typing(let accepted) = task.body else { return nil }
        guard !PracticeAnswer.normalize(text).isEmpty else { return nil }
        let value = Self.truncated(text, to: Self.maxValueLength)
        return finishSubmit(.submitValue(value), isCorrect: PracticeAnswer.matches(value, accepted: accepted))
    }

    @discardableResult
    mutating func submitTiles() -> Bool? {
        guard canAnswer, case .reorder(_, let accepted) = task.body, !placedTileIDs.isEmpty else { return nil }
        let text = placedTiles.map(\.text).joined()
        return finishSubmit(.submitTiles(placedTileIDs), isCorrect: PracticeAnswer.matches(text, accepted: accepted))
    }

    /// `edits` maps grapheme index to its replacement; an empty one deletes the grapheme.
    /// Like the backend, scores the repaired word, so any set of fixes that spells it right counts.
    @discardableResult
    mutating func submitRepair(edits: [Int: String]) -> Bool? {
        guard canAnswer, case .surgery(let word, let wrongIndex, let expected) = task.body else { return nil }
        let letters = PracticeAnswer.graphemes(word)
        guard !edits.isEmpty, edits.count <= Self.maxRepairEdits, edits.keys.allSatisfy(letters.indices.contains)
        else { return nil }
        let fixes = edits.keys.sorted().map {
            RepairEdit(graphemeIndex: $0, replacement: Self.truncated(edits[$0] ?? "", to: Self.maxReplacementLength))
        }
        let repaired = Self.applying(fixes, to: letters)
        let correct = Self.applying([RepairEdit(graphemeIndex: wrongIndex, replacement: expected)], to: letters)
        let isCorrect = PracticeAnswer.normalize(repaired) == PracticeAnswer.normalize(correct)
        return finishSubmit(.submitRepair(fixes), isCorrect: isCorrect)
    }

    private static func applying(_ fixes: [RepairEdit], to letters: [String]) -> String {
        let byIndex = Dictionary(fixes.map { ($0.graphemeIndex, $0.replacement) }) { $1 }
        return letters.enumerated().map { byIndex[$0.offset] ?? $0.element }.joined()
    }

    /// Correct pairs lock. Tries count per left item. The task ends by itself once no left item is open.
    @discardableResult
    mutating func submitPair(leftID: Int, rightID: Int) -> Bool? {
        guard !isFinished, hasRoomForEvent, case .match(let left, let right, let correct) = task.body,
              left.contains(where: { $0.id == leftID }), right.contains(where: { $0.id == rightID }),
              !matchedLeftIDs.contains(leftID), !exhaustedLeftIDs.contains(leftID)
        else { return nil }
        append(.pair(leftID: leftID, rightID: rightID))
        let isCorrect = correct.contains { $0.leftId == leftID && $0.rightId == rightID }
        if isCorrect {
            matchedLeftIDs.insert(leftID)
            lastWrongPair = nil
        } else {
            lastWrongPair = PairKey(leftId: leftID, rightId: rightID)
            missesByLeftID[leftID, default: 0] += 1
            if isOutOfTries(missesByLeftID[leftID, default: 0]) { exhaustedLeftIDs.insert(leftID) }
        }
        if matchedLeftIDs.count == left.count {
            status = .solved
        } else if matchedLeftIDs.count + exhaustedLeftIDs.count == left.count {
            status = .exhausted
        }
        endIfOutOfEvents()
        return isCorrect
    }

    // MARK: Tiles

    /// Every move is recorded because the backend replays them to rebuild the answer row.
    mutating func tapTile(_ id: Int) {
        guard canAnswer, bankTiles.contains(where: { $0.id == id }) else { return }
        placedTileIDs.append(id)
        append(.tapTile(id))
        endIfOutOfEvents()
    }

    mutating func removeTile(_ id: Int) {
        guard canAnswer, placedTileIDs.contains(id) else { return }
        placedTileIDs.removeAll { $0 == id }
        append(.removeTile(id))
        endIfOutOfEvents()
    }

    mutating func moveTile(_ id: Int, to index: Int) {
        guard canAnswer, placedTileIDs.contains(id), placedTileIDs.indices.contains(index),
              placedTileIDs[index] != id
        else { return }
        placedTileIDs.removeAll { $0 == id }
        placedTileIDs.insert(id, at: index)
        append(.moveTile(id, toIndex: index))
        endIfOutOfEvents()
    }

    // MARK: Help

    mutating func useHint() {
        guard canUseHint else { return }
        hintsUsed += 1
        append(.hint)
        endIfOutOfEvents()
    }

    mutating func reveal() {
        guard canReveal else { return }
        append(.reveal)
        status = .revealed
    }

    mutating func tryAgain() {
        guard status == .wrong else { return }
        status = .answering
        lastWrongOptionID = nil
    }

    // MARK: Recording. Exactly one terminal event, whatever happened before it.

    var canRecordAgain: Bool { !isOutOfTries(assessmentCount) }

    /// Every receipt counts, invalid audio included. An upload that got none does not.
    mutating func countAssessment(passed: Bool = false) {
        assessmentCount += 1
        if assessmentCount == 1 { passedFirstTake = passed }
    }

    mutating func finishRecording(receiptID: String) {
        guard !isFinished, task.template == .recording else { return }
        append(.assessed(receiptID: receiptID))
        status = .recorded
    }

    /// On-device takes are one `transcribed` event each and can't mix with the other two.
    mutating func recordTranscript(_ transcript: String, passed: Bool = false) {
        guard !isFinished, task.template == .recording, canRecordAgain else { return }
        append(.transcribed(Self.truncated(transcript, to: 200)))
        countAssessment(passed: passed)
    }

    var hasTranscripts: Bool {
        events.contains { if case .transcribed = $0.action { true } else { false } }
    }

    mutating func finishTranscribed() {
        guard !isFinished, hasTranscripts else { return }
        status = .recorded
    }

    mutating func markRecordingUnavailable(reason: String) {
        guard !isFinished, task.template == .recording else { return }
        append(.unavailable(reason: reason))
        status = .recorded
    }

    // MARK: Audio prompt delivery

    mutating func recordAudioPlayback(succeeded: Bool) {
        if succeeded {
            audioDelivery = .audio
        } else if audioDelivery == .none {
            audioDelivery = .fallback
        }
    }

    // MARK: Private

    private var canAnswer: Bool { status == .answering && hasRoomForEvent }

    /// One slot stays free for the event that ends the task.
    private var hasRoomForEvent: Bool { events.count < Self.maxEvents - 1 }

    /// One more submit past this point rejects the entire commit.
    private func isOutOfTries(_ tries: Int) -> Bool {
        task.maxRetries.map { tries > $0 } ?? false
    }

    private mutating func append(_ action: TaskEvent.Action) {
        events.append(TaskEvent(seq: events.count + 1, action: action))
    }

    private mutating func finishSubmit(_ action: TaskEvent.Action, isCorrect: Bool) -> Bool {
        append(action)
        submitCount += 1
        status = isCorrect ? .solved : (isOutOfTries(submitCount) ? .exhausted : .wrong)
        endIfOutOfEvents()
        return isCorrect
    }

    /// Past the limit the commit would be rejected, so the task ends in whichever way is still valid.
    private mutating func endIfOutOfEvents() {
        guard !isFinished, !hasRoomForEvent else { return }
        if submitCount > 0, task.template != .match {
            status = .exhausted
        } else if requiresSubmission {
            append(.submitTiles(placedTileIDs))
            submitCount += 1
            status = .exhausted
        } else {
            append(.reveal)
            status = .revealed
        }
    }

    /// The backend's limits count UTF-16 units.
    private static func truncated(_ text: String, to limit: Int) -> String {
        guard text.utf16.count > limit else { return text }
        var result = ""
        for character in text {
            guard result.utf16.count + character.utf16.count <= limit else { break }
            result.append(character)
        }
        return result
    }
}

extension TaskAttempt {
    /// The answer in words, for after it is solved or revealed.
    var solutionText: String? {
        switch task.body {
        case .choice(let options, _, let correct):
            options.first { $0.id == correct }?.text
        case .typing(let accepted), .reorder(_, let accepted):
            accepted.first
        case .surgery(let word, let index, let replacement):
            PracticeAnswer.graphemes(word).enumerated()
                .map { $0.offset == index ? replacement : $0.element }
                .joined()
        case .match, .recording:
            nil
        }
    }

    /// Match only: the pairs that ran out of tries, one per line. Pairs the learner got stay on the board.
    var missedPairsText: String? {
        pairsText { exhaustedLeftIDs.contains($0.id) }
    }

    /// Every pair of a match, for when the learner asks to see the answer.
    var allPairsText: String? {
        pairsText { _ in true }
    }

    private func pairsText(where isIncluded: (TaskOption) -> Bool) -> String? {
        guard case .match(let left, let right, let correct) = task.body else { return nil }
        return left.filter(isIncluded).compactMap { term in
            guard let rightID = correct.first(where: { $0.leftId == term.id })?.rightId,
                  let gloss = right.first(where: { $0.id == rightID })
            else { return nil }
            return "\(term.text) — \(gloss.text)"
        }
        .joined(separator: "\n")
    }
}
