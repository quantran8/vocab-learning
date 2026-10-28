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

    @ObservationIgnored let feedback: SettingsAwareFeedback
    @ObservationIgnored private let defaults: UserDefaults?

    private enum Keys {
        static let haptics = "settings.haptics"
        static let reduceMotion = "settings.reduceMotion"
    }

    /// Pass `nil` defaults for an in-memory store (previews, tests).
    init(feedback: SettingsAwareFeedback, defaults: UserDefaults? = .standard) {
        self.feedback = feedback
        self.defaults = defaults
        hapticsEnabled = defaults?.object(forKey: Keys.haptics) as? Bool ?? true
        reduceMotion = defaults?.bool(forKey: Keys.reduceMotion) ?? false
        feedback.isEnabled = hapticsEnabled
    }
}
