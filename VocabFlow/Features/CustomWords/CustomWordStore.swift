import Foundation
import Observation

/// Adding a word of the learner's own, and the list of words they added.
@Observable
@MainActor
final class CustomWordStore {
    enum LookupPhase: Equatable {
        case idle, loading
        case result(CustomWordLookup)
        /// `isNew` is false when the word was already on the roadmap.
        case added(lemma: String, isNew: Bool, ipa: String? = nil)
        case failed(String, canRetry: Bool)
    }

    enum ListPhase: Equatable {
        case loading, ready, failed(String)
    }

    private(set) var phase: LookupPhase = .idle
    /// Why the last add didn't go through. The result stays on screen so the learner can act on it.
    private(set) var notice: String?
    private(set) var isAdding = false
    /// The word an "other meaning" search started from, which going back returns to.
    private(set) var baseWord: ExistingWord?

    private(set) var listPhase: ListPhase = .loading
    private(set) var words: [CustomWord] = []
    /// A failed change to the list. The list itself stays usable.
    private(set) var listError: String?
    private(set) var busyMeaningIDs: Set<String> = []

    /// Set by the app so Home's figures follow the roadmap.
    var onRoadmapChanged: (@MainActor () async -> Void)?

    private let api: VocabAPI
    private let audio: AudioClipPlaying
    private var lastQuery: CustomWordQuery?
    /// Identifies the current lookup: a slow answer for a closed sheet must not land in the next one.
    private var lookupToken = UUID()

    var lastContext: String { lastQuery?.context ?? "" }

    init(api: VocabAPI, audio: AudioClipPlaying) {
        self.api = api
        self.audio = audio
    }

    // MARK: Lookup and add

    func lookup(_ text: String, context: String? = nil) async {
        notice = nil
        if context != nil, case .result(.existing(let word)) = phase {
            baseWord = word
        }
        await run(CustomWordQuery(text: text.trimmed, context: context?.trimmed))
    }

    func retryLookup() async {
        guard let lastQuery else { return }
        notice = nil
        await run(lastQuery)
    }

    private func run(_ query: CustomWordQuery) async {
        let token = UUID()
        lookupToken = token
        lastQuery = query
        phase = .loading
        do {
            let result = try await api.lookupCustomWord(query)
            guard token == lookupToken else { return }
            phase = .result(result)
        } catch {
            guard token == lookupToken else { return }
            let failure = error.asAPIError
            phase = .failed(failure.userMessage, canRetry: failure.isRetryable)
        }
    }

    func add(_ addition: CustomWordAddition, lemma: String, ipa: String? = nil) async {
        guard !isAdding else { return }
        isAdding = true
        defer { isAdding = false }
        notice = nil
        let token = lookupToken
        do {
            let response = try await api.addCustomWord(addition)
            await onRoadmapChanged?()
            guard token == lookupToken else { return }
            phase = .added(lemma: lemma, isNew: response.added, ipa: ipa)
        } catch {
            guard token == lookupToken else { return }
            await recover(from: error.asAPIError)
        }
    }

    /// A stale draft is the client's cue to look again, so the learner never sees it as an error.
    private func recover(from failure: APIError) async {
        switch failure.code {
        case "WORD_ALREADY_EXISTS", "CUSTOM_WORD_INVALID":
            await retryLookup()
        case "CUSTOM_WORD_UNAVAILABLE":
            await retryLookup()
            notice = failure.userMessage
        default:
            notice = failure.userMessage
        }
    }

    func resetLookup() {
        lookupToken = UUID()
        lastQuery = nil
        baseWord = nil
        phase = .idle
        notice = nil
    }

    func goBack() {
        guard let word = baseWord else { return resetLookup() }
        lookupToken = UUID()
        lastQuery = CustomWordQuery(text: word.lemma)
        baseWord = nil
        phase = .result(.existing(word))
        notice = nil
    }

    // MARK: The learner's list

    func loadWords() async {
        do {
            words = try await api.customWords()
            listPhase = .ready
        } catch {
            let message = error.asAPIError.userMessage
            if words.isEmpty {
                listPhase = .failed(message)
            } else {
                listError = message
            }
        }
    }

    func remove(_ word: CustomWord) async {
        await change(word, treatMissingAsDone: true) { [api] in
            try await api.removeCustomWord(meaningID: word.meaningId)
        }
        await onRoadmapChanged?()
    }

    func saveOverride(_ edits: CustomWordEdits, for word: CustomWord) async {
        await change(word) { [api] in
            try await api.overrideCustomWord(meaningID: word.meaningId, edits: edits)
        }
    }

    func restoreOriginal(_ word: CustomWord) async {
        await change(word) { [api] in
            try await api.clearCustomWordOverride(meaningID: word.meaningId)
        }
    }

    /// A 404 means another device already took the word off, so the list is what needs fixing.
    private func change(_ word: CustomWord, treatMissingAsDone: Bool = false, _ request: () async throws -> Void) async {
        busyMeaningIDs.insert(word.meaningId)
        defer { busyMeaningIDs.remove(word.meaningId) }
        listError = nil
        do {
            try await request()
        } catch {
            let failure = error.asAPIError
            if failure.status == 404 {
                if !treatMissingAsDone {
                    listError = String(localized: "This word is no longer on your learning path.")
                }
            } else {
                listError = failure.userMessage
                return
            }
        }
        await loadWords()
    }

    func play(_ word: CustomWord) {
        guard let url = word.audioUrl else { return }
        Task { _ = await audio.play(url) }
    }

    func stopAudio() {
        audio.stop()
    }

    func reset() {
        resetLookup()
        audio.stop()
        listPhase = .loading
        words = []
        listError = nil
        busyMeaningIDs = []
    }
}
