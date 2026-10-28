import UIKit

protocol FeedbackProviding {
    func selectionChanged()
    func success()
    func error()
}

final class FeedbackHaptics: FeedbackProviding {
    private let selection = UISelectionFeedbackGenerator()
    private let notification = UINotificationFeedbackGenerator()

    init() {
        selection.prepare()
        notification.prepare()
    }

    func selectionChanged() {
        selection.selectionChanged()
        selection.prepare()
    }

    func success() {
        notification.notificationOccurred(.success)
        notification.prepare()
    }

    func error() {
        notification.notificationOccurred(.error)
        notification.prepare()
    }
}

struct NoOpFeedback: FeedbackProviding {
    func selectionChanged() {}
    func success() {}
    func error() {}
}

/// Forwards to another provider only while haptics are switched on in Settings.
final class SettingsAwareFeedback: FeedbackProviding {
    var isEnabled = true
    private let base: FeedbackProviding

    init(base: FeedbackProviding) {
        self.base = base
    }

    func selectionChanged() {
        if isEnabled { base.selectionChanged() }
    }

    func success() {
        if isEnabled { base.success() }
    }

    func error() {
        if isEnabled { base.error() }
    }
}
