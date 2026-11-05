import Foundation
import Observation
import UserNotifications

protocol PreferencesStoring: AnyObject {
    var preferences: LearningPreferences? { get set }
    var hasCompletedOnboarding: Bool { get set }
}

final class UserDefaultsPreferencesStore: PreferencesStoring {
    private let defaults: UserDefaults
    private static let preferencesKey = "learningPreferences"
    /// Override at launch with `-hasCompletedOnboarding NO` to replay onboarding.
    private static let completedKey = "hasCompletedOnboarding"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var preferences: LearningPreferences? {
        get {
            defaults.data(forKey: Self.preferencesKey)
                .flatMap { try? JSONDecoder().decode(LearningPreferences.self, from: $0) }
        }
        set {
            defaults.set(newValue.flatMap { try? JSONEncoder().encode($0) }, forKey: Self.preferencesKey)
        }
    }

    var hasCompletedOnboarding: Bool {
        get { defaults.bool(forKey: Self.completedKey) }
        set { defaults.set(newValue, forKey: Self.completedKey) }
    }
}

final class InMemoryPreferencesStore: PreferencesStoring {
    var preferences: LearningPreferences?
    var hasCompletedOnboarding: Bool

    init(preferences: LearningPreferences? = nil, hasCompletedOnboarding: Bool = false) {
        self.preferences = preferences
        self.hasCompletedOnboarding = hasCompletedOnboarding
    }
}

protocol ReminderScheduling {
    func apply(_ preferences: LearningPreferences) async
}

/// One repeating local notification per learning day. Permission is only asked when reminders are on.
struct NotificationReminderScheduler: ReminderScheduling {
    private static func identifier(weekday: Int) -> String { "learning-reminder-\(weekday)" }

    func apply(_ preferences: LearningPreferences) async {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: LearningPreferences.allWeekdays.map(Self.identifier))
        guard preferences.reminderEnabled, !preferences.learningDays.isEmpty else { return }
        guard (try? await center.requestAuthorization(options: [.alert, .sound])) == true else { return }

        let content = UNMutableNotificationContent()
        content.title = String(localized: "Time for your flow", bundle: .appLanguage)
        content.body = String(localized: "\(preferences.wordsPerDay) new words are waiting.", bundle: .appLanguage)
        content.sound = .default

        for weekday in preferences.learningDays {
            var components = DateComponents()
            components.weekday = weekday
            components.hour = preferences.reminderHour
            components.minute = preferences.reminderMinute
            let request = UNNotificationRequest(
                identifier: Self.identifier(weekday: weekday),
                content: content,
                trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
            )
            try? await center.add(request)
        }
    }
}

struct NoReminders: ReminderScheduling {
    func apply(_ preferences: LearningPreferences) async {}
}

/// The saved learning plan. Onboarding creates it; Profile edits it. Every save reschedules reminders.
@Observable
@MainActor
final class LearningPlanStore {
    private(set) var preferences: LearningPreferences?
    private(set) var hasCompletedOnboarding: Bool

    private let storage: PreferencesStoring
    private let reminders: ReminderScheduling

    init(storage: PreferencesStoring, reminders: ReminderScheduling) {
        self.storage = storage
        self.reminders = reminders
        preferences = storage.preferences
        hasCompletedOnboarding = storage.hasCompletedOnboarding
    }

    var current: LearningPreferences { preferences ?? .default }

    func save(_ preferences: LearningPreferences) {
        guard preferences.isComplete else { return }
        storage.preferences = preferences
        self.preferences = preferences
        let reminders = reminders
        Task { await reminders.apply(preferences) }
    }

    func rescheduleReminders() {
        let reminders = reminders
        let preferences = current
        Task { await reminders.apply(preferences) }
    }

    func completeOnboarding() {
        guard preferences != nil else { return }
        storage.hasCompletedOnboarding = true
        hasCompletedOnboarding = true
    }

    /// The account already has a plan (new device, or returning after sign-out). The server owns the
    /// scope and daily goal; learning days and reminders stay on this device.
    func adopt(_ scope: LearningScope, wordsPerDay: Int) {
        var next = current
        next.collectionID = scope.collectionId
        next.topicIDs = Set(scope.topicIds)
        next.wordsPerDay = min(wordsPerDay, LearningPreferences.wordsPerDayRange.upperBound)
        storage.preferences = next
        preferences = next
        storage.hasCompletedOnboarding = true
        hasCompletedOnboarding = true
    }

    /// The signed-in account hasn't finished onboarding, whatever this device remembers.
    func resetOnboarding() {
        storage.hasCompletedOnboarding = false
        hasCompletedOnboarding = false
    }

    /// The account was deleted: forget the plan and cancel its reminders.
    func erase() {
        var off = current
        off.reminderEnabled = false
        let reminders = reminders
        Task { await reminders.apply(off) }
        storage.preferences = nil
        preferences = nil
        resetOnboarding()
    }
}
