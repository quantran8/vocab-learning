import Foundation
import Observation

/// App-wide preferences that live outside the learning plan.
@Observable
@MainActor
final class AppSettingsStore {
    var hapticsEnabled: Bool {
        didSet {
            defaults?.set(hapticsEnabled, forKey: Keys.haptics)
            feedback.isEnabled = hapticsEnabled
        }
    }

    /// Adds to the system Reduce Motion setting; it never turns motion back on.
    var reduceMotion: Bool {
        didSet { defaults?.set(reduceMotion, forKey: Keys.reduceMotion) }
    }

    /// Experiment: "I know this" before each new word in Daily. Off by default.
    var offersKnownCheck: Bool {
        didSet { defaults?.set(offersKnownCheck, forKey: Keys.knownCheck) }
    }

    /// `nil` until the learner has chosen, which is what puts the language step on screen.
    private(set) var language: AppLanguage?

    @ObservationIgnored let feedback: SettingsAwareFeedback
    @ObservationIgnored private let defaults: UserDefaults?

    private enum Keys {
        static let haptics = "settings.haptics"
        static let reduceMotion = "settings.reduceMotion"
        static let knownCheck = "settings.knownCheck"
        static let language = "settings.language"
        /// The system's per-app language: read at launch for everything outside SwiftUI's
        /// environment, such as permission prompts, and changed by iOS Settings › Syll.
        static let systemLanguages = "AppleLanguages"
    }

    /// Pass `nil` defaults for an in-memory store (previews, tests).
    init(feedback: SettingsAwareFeedback, defaults: UserDefaults? = .standard) {
        self.feedback = feedback
        self.defaults = defaults
        hapticsEnabled = defaults?.object(forKey: Keys.haptics) as? Bool ?? true
        reduceMotion = defaults?.bool(forKey: Keys.reduceMotion) ?? false
        offersKnownCheck = defaults?.bool(forKey: Keys.knownCheck) ?? false
        feedback.isEnabled = hapticsEnabled
        language = Self.savedLanguage(in: defaults)
        if let language { AppLanguage.active = language }
    }

    /// Applies at once, and from the next launch on for what only reads the language at launch.
    func chooseLanguage(_ language: AppLanguage) {
        self.language = language
        AppLanguage.active = language
        defaults?.set(language.rawValue, forKey: Keys.language)
        defaults?.set([language.rawValue], forKey: Keys.systemLanguages)
    }

    /// A change in iOS Settings relaunches the app and wins over the saved choice.
    private static func savedLanguage(in defaults: UserDefaults?) -> AppLanguage? {
        guard let saved = defaults?.string(forKey: Keys.language).flatMap(AppLanguage.init(rawValue:)) else { return nil }
        return defaults?.stringArray(forKey: Keys.systemLanguages)?.first.flatMap(AppLanguage.init(languageTag:)) ?? saved
    }
}
