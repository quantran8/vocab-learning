import XCTest
@testable import VocabFlow

@MainActor
final class AccountDeletionTests: XCTestCase {
    private func signedInStore(_ api: StubVocabAPI) async -> AuthStore {
        let store = AuthStore(api: api)
        await store.restore()
        return store
    }

    private func unauthorized() -> APIError {
        .server(status: 401, code: "UNAUTHORIZED", message: "", retryable: false, requestID: nil)
    }

    func testSuccessEndsTheSessionAndErasesTheDevice() async {
        let api = StubVocabAPI()
        let store = await signedInStore(api)
        var erased = 0
        var signedOut = 0
        store.onAccountDeleted = { erased += 1 }
        store.onSignedOut = { signedOut += 1 }

        await store.deleteAccount()

        XCTAssertEqual(api.deleteAccountCalls, 1)
        XCTAssertEqual(api.signOutCalls, 1)
        XCTAssertEqual(erased, 1)
        XCTAssertEqual(signedOut, 1)
        XCTAssertEqual(store.phase, .signedOut)
        XCTAssertNotNil(store.accountDeletedNotice)
        XCTAssertNil(store.errorMessage)
        XCTAssertFalse(store.isDeletingAccount)
    }

    func testFailureKeepsTheSessionAndTheDeviceData() async {
        let api = StubVocabAPI()
        api.deleteAccountError = .transport
        let store = await signedInStore(api)
        var erased = 0
        store.onAccountDeleted = { erased += 1 }

        await store.deleteAccount()

        XCTAssertEqual(api.signOutCalls, 0)
        XCTAssertEqual(erased, 0)
        XCTAssertEqual(store.phase, .signedIn)
        XCTAssertNotNil(store.accountDeletionError)
        XCTAssertNil(store.accountDeletedNotice)
        XCTAssertFalse(store.isDeletingAccount)
    }

    func testRetryClearsThePreviousError() async {
        let api = StubVocabAPI()
        api.deleteAccountError = .transport
        let store = await signedInStore(api)
        await store.deleteAccount()

        api.deleteAccountError = nil
        await store.deleteAccount()

        XCTAssertNil(store.accountDeletionError)
        XCTAssertEqual(store.phase, .signedOut)
    }

    /// The account may still exist, so the sign-in screen must not say it was deleted.
    func testRejectedSessionAsksToLogInAgain() async {
        let api = StubVocabAPI()
        api.deleteAccountError = unauthorized()
        let store = await signedInStore(api)

        await store.deleteAccount()

        XCTAssertEqual(store.phase, .signedOut)
        XCTAssertNotNil(store.errorMessage)
        XCTAssertNil(store.accountDeletedNotice)
        XCTAssertNil(store.accountDeletionError)
    }

    func testNoticeClearsWhenLoggingInAgain() async {
        let store = await signedInStore(StubVocabAPI())
        await store.deleteAccount()

        await store.logIn(email: "a@example.com", password: "correct-horse")

        XCTAssertNil(store.accountDeletedNotice)
    }

    func testPlanEraseForgetsThePlanAndCancelsReminders() async {
        var preferences = LearningPreferences.default
        preferences.reminderEnabled = true
        let storage = InMemoryPreferencesStore(preferences: preferences, hasCompletedOnboarding: true)
        let cancelled = expectation(description: "reminders applied")
        let reminders = RecordingReminders { applied in
            XCTAssertFalse(applied.reminderEnabled)
            cancelled.fulfill()
        }
        let plan = LearningPlanStore(storage: storage, reminders: reminders)

        plan.erase()
        await fulfillment(of: [cancelled], timeout: 1)

        XCTAssertNil(plan.preferences)
        XCTAssertFalse(plan.hasCompletedOnboarding)
        XCTAssertNil(storage.preferences)
        XCTAssertFalse(storage.hasCompletedOnboarding)
    }

    func testProgressEraseRemovesTheStoredHistory() throws {
        let suite = "AccountDeletionTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(try JSONEncoder().encode(LearningProgress()), forKey: "learningProgress")
        let store = ProgressStore(defaults: defaults)

        store.erase()

        XCTAssertNil(defaults.object(forKey: "learningProgress"))
    }
}

private struct RecordingReminders: ReminderScheduling {
    let onApply: (LearningPreferences) -> Void

    func apply(_ preferences: LearningPreferences) async {
        onApply(preferences)
    }
}
