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
    /// The server's Journey: it alone decides which node is done, current or locked.
    private(set) var journey: Journey?
    /// Set when the Journey couldn't load; whatever was on screen stays.
    private(set) var journeyError: String?
    private(set) var isLoadingOlderJourney = false
    /// The review-load choice shows at most once per launch, whatever the server says.
    private(set) var hasShownReviewChoice = false

    static let wordsPageSize = 50
    static let journeyHistoryPage = 2

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
            // Read before `adopt`, which stores the defaults when this device has no plan yet.
            let localWeeklyGoal = plan.preferences?.weeklySessionGoal
            await syncDeviceSettings(profile.settings, weeklySessionGoal: localWeeklyGoal)
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
        async let path: Void = refreshJourney()
        // Topic progress ("45/120", "Finished") moves with every session.
        async let catalog = try? api.catalog()
        if let home = await home { self.home = home }
        if let catalog = await catalog { TopicCatalog.update(with: catalog) }
        if let challenges = await challenges { self.challenges = challenges }
        if let stats = await stats { wordStats = stats }
        await library
        await path
        await profile
    }

    /// Reloads the first page. History pages already loaded below it are kept, so a refresh
    /// after a session doesn't pull the list away from where the learner scrolled.
    func refreshJourney() async {
        do {
            let fresh = try await api.journey(historyLimit: Self.journeyHistoryPage, before: nil)
            if let old = journey, let freshOldest = fresh.segments.last?.segmentNo,
               let oldOldest = old.segments.last?.segmentNo, oldOldest < freshOldest {
                var older = old
                older.segments = old.segments.filter { $0.segmentNo < freshOldest }
                journey = fresh.appendingHistory(older)
            } else {
                journey = fresh
            }
            journeyError = nil
        } catch {
            if !Task.isCancelled { journeyError = error.asAPIError.userMessage }
        }
    }

    /// Appends the next older page, if there is one and nothing is loading already.
    func loadOlderJourney() async {
        guard let current = journey, current.hasMoreHistory, let cursor = current.nextHistoryCursor,
              !isLoadingOlderJourney else { return }
        isLoadingOlderJourney = true
        defer { isLoadingOlderJourney = false }
        do {
            let page = try await api.journey(historyLimit: Self.journeyHistoryPage, before: cursor)
            // A refresh may have replaced the Journey meanwhile; merge into whatever is there now.
            if let latest = journey { journey = latest.appendingHistory(page) }
        } catch {
            if !Task.isCancelled { journeyError = error.asAPIError.userMessage }
        }
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
        try await api.updateSettings(SettingsUpdate(dailyNewWordGoal: preferences.wordsPerDay, weeklySessionGoal: preferences.weeklySessionGoal))
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

    /// Whether Home should offer the review-load choice now. The caller also keeps it out of a session.
    var shouldOfferReviewChoice: Bool {
        !hasShownReviewChoice && home?.reviewLoad?.promptChoice == true
    }

    /// Any choice, including dismissing, counts as seen here and on the learner's other devices.
    func acknowledgeReviewChoice() async {
        hasShownReviewChoice = true
        guard let backlog = home?.reviewLoad?.backlog else { return }
        try? await api.acknowledgeReviewLoad(backlog: backlog)
        await refreshHome()
    }

    /// Lowers new words for now. `until` nil with `.untilDate` ends with the learner's Sunday.
    func setNewWordOverride(value: Int, mode: NewWordOverrideMode) async throws {
        _ = try await api.setNewWordOverride(value: value, mode: mode, until: nil)
        await refreshHome()
    }

    func clearNewWordOverride() async throws {
        try await api.clearNewWordOverride()
        await refreshHome()
    }

    func setAutoBalance(_ enabled: Bool) async throws {
        try await api.updateSettings(SettingsUpdate(autoBalanceNewWords: enabled))
        async let profile: Void = reloadProfile()
        async let home: Void = refreshHome()
        _ = await (profile, home)
    }

    /// The active collection is always reviewed; the server rejects pausing it.
    func setReviewPaused(_ paused: Bool, collectionID: String) async throws {
        try await api.setReviewPaused(collectionID: collectionID, paused: paused)
        async let profile: Void = reloadProfile()
        async let home: Void = refreshHome()
        _ = await (profile, home)
    }

    func isReviewPaused(collectionID: String) -> Bool {
        profile?.reviewPauses?.contains { $0.collectionId == collectionID } ?? false
    }

    private func refreshHome() async {
        if let home = try? await api.learnHome() { self.home = home }
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
        journey = nil
        journeyError = nil
        isLoadingOlderJourney = false
        hasShownReviewChoice = false
    }

    /// `timeZone` defines the learner's "day" for the daily goal; `uiLocale` localizes the catalog.
    /// The learning days only live on the device, so their count goes up here too: a plan saved before the
    /// backend knew about it (or while a save failed) still sizes the learner's Journey segments.
    /// A device without a saved plan sends nothing, so it never overwrites the server with defaults.
    private func syncDeviceSettings(_ settings: UserSettings, weeklySessionGoal: Int?) async {
        let timeZone = TimeZone.current.identifier
        let uiLocale = AppLanguage.active.uiLocale
        let goal = weeklySessionGoal.flatMap { settings.weeklySessionGoal != $0 ? $0 : nil }
        guard settings.timeZone != timeZone || settings.uiLocale != uiLocale || goal != nil else { return }
        try? await api.updateSettings(SettingsUpdate(uiLocale: uiLocale, timeZone: timeZone, weeklySessionGoal: goal))
    }
}
