import Foundation
import Observation

/// The signed-in learner's server state: profile, Home figures and word library.
@Observable
@MainActor
final class LearnerStore {
    enum Phase: Equatable {
        case loading, ready, failed(String)
    }

    private(set) var phase: Phase = .loading
    private(set) var profile: UserProfile?
    private(set) var home: LearnHome?
    private(set) var challenges: [CheckpointChallenge] = []
    /// The pages loaded so far for `wordsQuery`, not the whole library.
    private(set) var words: [WordProgress] = []
    private(set) var wordStats: WordStats?
    private(set) var wordsQuery = ""
    private(set) var hasMoreWords = false
    private(set) var isSearchingWords = false
    private(set) var isLoadingMoreWords = false
    private(set) var wordsError: String?

    static let wordsPageSize = 50

    /// Bumped by every first-page load, so answers for an older query or list are ignored.
    private var wordsGeneration = 0
    private let api: VocabAPI
    private let plan: LearningPlanStore

    init(api: VocabAPI, plan: LearningPlanStore) {
        self.api = api
        self.plan = plan
    }

    /// Runs after sign-in. `GET /me` decides between onboarding and Home, so the route stays on
    /// the loading screen until it answers.
    func load() async {
        phase = .loading
        do {
            let profile = try await api.profile()
            self.profile = profile
            await syncDeviceSettings(profile.settings)
            if let scope = profile.scope, profile.hasFinishedOnboarding {
                TopicCatalog.update(with: try await api.catalog())
                plan.adopt(scope, wordsPerDay: profile.settings.dailyNewWordGoal)
            } else {
                plan.resetOnboarding()
            }
            phase = .ready
        } catch {
            phase = .failed(error.asAPIError.userMessage)
        }
    }

    /// Runs whenever the main shell appears, so also after onboarding and every session.
    /// Non-fatal: Home keeps what it has if a refresh fails.
    /// The profile is included because onboarding saves the level and scope after `load()` read it.
    func refresh() async {
        async let profile: Void = reloadProfile()
        async let home = try? api.learnHome()
        async let challenges = try? api.checkpointChallenges()
        async let stats = try? api.wordStats()
        async let library: Void = loadWords(matching: wordsQuery)
        if let home = await home { self.home = home }
        if let challenges = await challenges { self.challenges = challenges }
        if let stats = await stats { wordStats = stats }
        await library
        await profile
    }

    /// Replaces the list with the first page for `query`. A failed reload keeps what is on screen,
    /// but a failed new search clears it: those rows don't answer the new query.
    func loadWords(matching query: String) async {
        wordsGeneration += 1
        let generation = wordsGeneration
        let isNewQuery = query != wordsQuery
        wordsQuery = query
        isSearchingWords = true
        isLoadingMoreWords = false
        wordsError = nil
        do {
            let page = try await api.words(limit: Self.wordsPageSize, offset: 0, query: query)
            guard generation == wordsGeneration else { return }
            words = page
            hasMoreWords = page.count == Self.wordsPageSize
        } catch {
            guard generation == wordsGeneration else { return }
            if isNewQuery {
                words = []
                hasMoreWords = false
            }
            if !Task.isCancelled { wordsError = error.asAPIError.userMessage }
        }
        isSearchingWords = false
    }

    /// Appends the next page, if there is one and nothing is loading already.
    func loadMoreWords() async {
        guard hasMoreWords, !isLoadingMoreWords, !isSearchingWords else { return }
        let generation = wordsGeneration
        isLoadingMoreWords = true
        wordsError = nil
        do {
            let page = try await api.words(limit: Self.wordsPageSize, offset: words.count, query: wordsQuery)
            guard generation == wordsGeneration else { return }
            // Learning a word between pages shifts the offsets, so a word can come back twice.
            let known = Set(words.map(\.id))
            words += page.filter { !known.contains($0.id) }
            hasMoreWords = page.count == Self.wordsPageSize
        } catch {
            guard generation == wordsGeneration else { return }
            if !Task.isCancelled { wordsError = error.asAPIError.userMessage }
        }
        isLoadingMoreWords = false
    }

    /// Skill states are only read when a word is opened.
    func wordDetail(id: String) async throws -> WordDetail {
        try await api.wordDetail(id: id)
    }

    /// Scope and goal go to the server first, so a failed save leaves the local plan unchanged.
    func savePlan(_ preferences: LearningPreferences) async throws {
        try await api.updateScope(LearningScope(collectionId: preferences.collectionID, topicIds: Array(preferences.topicIDs)))
        try await api.updateSettings(SettingsUpdate(dailyNewWordGoal: preferences.wordsPerDay))
        plan.save(preferences)
    }

    /// The level goes to the server first; the profile is re-read so Profile shows what the server kept.
    func updateLevel(_ level: CEFRLevel) async throws {
        try await api.updateLevels(level)
        await reloadProfile()
    }

    /// The server holds the catalog's language, and scheduled reminders hold their text.
    /// A failed save is retried by the next `load()`, which compares `uiLocale` with the server's.
    func languageDidChange() async {
        plan.rescheduleReminders()
        try? await api.updateSettings(SettingsUpdate(uiLocale: AppLanguage.active.uiLocale))
        if let catalog = try? await api.catalog() { TopicCatalog.update(with: catalog) }
        await refresh()
    }

    func reloadProfile() async {
        if let profile = try? await api.profile() { self.profile = profile }
    }

    func reset() {
        phase = .loading
        profile = nil
        home = nil
        challenges = []
        wordsGeneration += 1
        words = []
        wordStats = nil
        wordsQuery = ""
        hasMoreWords = false
        isSearchingWords = false
        isLoadingMoreWords = false
        wordsError = nil
    }

    /// `timeZone` defines the learner's "day" for the daily goal; `uiLocale` localizes the catalog.
    private func syncDeviceSettings(_ settings: UserSettings) async {
        let timeZone = TimeZone.current.identifier
        let uiLocale = AppLanguage.active.uiLocale
        guard settings.timeZone != timeZone || settings.uiLocale != uiLocale else { return }
        try? await api.updateSettings(SettingsUpdate(uiLocale: uiLocale, timeZone: timeZone))
    }
}
