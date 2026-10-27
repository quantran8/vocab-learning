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
