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
    private(set) var words: [WordProgress] = []

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
    func refresh() async {
        async let home = try? api.learnHome()
        async let challenges = try? api.checkpointChallenges()
        async let words = try? api.allWords()
        if let home = await home { self.home = home }
        if let challenges = await challenges { self.challenges = challenges }
        if let words = await words { self.words = words }
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
        if let profile = try? await api.profile() { self.profile = profile }
    }

    func reset() {
        phase = .loading
        profile = nil
        home = nil
        challenges = []
        words = []
    }

    /// `timeZone` defines the learner's "day" for the daily goal; `uiLocale` localizes the catalog.
    private func syncDeviceSettings(_ settings: UserSettings) async {
        let timeZone = TimeZone.current.identifier
        let uiLocale = Bundle.main.preferredLocalizations.first?.hasPrefix("vi") == true ? "vi-VN" : "en-US"
        guard settings.timeZone != timeZone || settings.uiLocale != uiLocale else { return }
        try? await api.updateSettings(SettingsUpdate(uiLocale: uiLocale, timeZone: timeZone))
    }
}
