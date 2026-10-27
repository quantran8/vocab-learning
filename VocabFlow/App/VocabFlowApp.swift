import SwiftUI

@main
struct VocabFlowApp: App {
    @State private var store = SessionStore(
        content: DemoContentRepository().loadOrFail(),
        haptics: FeedbackHaptics()
    )

    var body: some Scene {
        WindowGroup {
            AppRootView()
                .environment(store)
        }
    }
}
