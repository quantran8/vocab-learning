import XCTest
@testable import VocabFlow

@MainActor
final class AppLanguageTests: XCTestCase {
    private var defaults: UserDefaults!
    private var suiteName: String!
    private var languageBefore: AppLanguage!

    override func setUp() async throws {
        suiteName = "AppLanguageTests-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        languageBefore = AppLanguage.active
    }

    override func tearDown() async throws {
        AppLanguage.active = languageBefore
        defaults.removePersistentDomain(forName: suiteName)
    }

    private func makeSettings() -> AppSettingsStore {
        AppSettingsStore(feedback: SettingsAwareFeedback(base: NoOpFeedback()), defaults: defaults)
    }

    func testNoLanguageIsChosenAtFirst() {
        XCTAssertNil(makeSettings().language)
    }

    func testAChoiceSurvivesARelaunch() {
        makeSettings().chooseLanguage(.vietnamese)
        AppLanguage.active = .english

        XCTAssertEqual(makeSettings().language, .vietnamese)
        XCTAssertEqual(AppLanguage.active, .vietnamese)
    }

    func testAChoiceAlsoSetsTheSystemLanguageForTheNextLaunch() {
        makeSettings().chooseLanguage(.vietnamese)
        XCTAssertEqual(defaults.stringArray(forKey: "AppleLanguages"), ["vi"])
    }

    func testIOSSettingsWinsOverTheSavedChoice() {
        makeSettings().chooseLanguage(.vietnamese)
        defaults.set(["en-US"], forKey: "AppleLanguages")
        XCTAssertEqual(makeSettings().language, .english)
    }

    func testStringsFollowTheChosenLanguageWithoutARelaunch() {
        let settings = makeSettings()

        settings.chooseLanguage(.vietnamese)
        XCTAssertEqual(String(localized: "Continue", bundle: .appLanguage), "Tiếp tục")

        settings.chooseLanguage(.english)
        XCTAssertEqual(String(localized: "Continue", bundle: .appLanguage), "Continue")
    }

    func testAChangedLanguageReachesTheServerAndRefreshesTheCatalog() async throws {
        let bundledCatalog = try await OfflineVocabAPI().catalog()
        defer { TopicCatalog.update(with: bundledCatalog) }
        let api = StubVocabAPI()
        let plan = LearningPlanStore(storage: InMemoryPreferencesStore(), reminders: NoReminders())
        let learner = LearnerStore(api: api, plan: plan)
        api.catalogCollections = [CatalogCollection(id: "c1", slug: "c1", title: "Hằng ngày", description: nil, topics: [])]
        makeSettings().chooseLanguage(.vietnamese)

        await learner.languageDidChange()

        XCTAssertEqual(api.settingsUpdates.last?.uiLocale, "vi-VN")
        XCTAssertEqual(TopicCatalog.collections.first?.name, "Hằng ngày")
    }
}
