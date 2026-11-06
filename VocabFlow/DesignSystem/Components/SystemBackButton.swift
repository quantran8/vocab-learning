import SwiftUI
import UIKit

/// The navigation bar's own back button before iOS 26: a black chevron, no title.
/// iOS 26+ already draws it as a Liquid Glass chevron, so it is left alone there.
enum SystemBackButton {
    static func configureAppearance() {
        guard #unavailable(iOS 26.0) else { return }
        // `.alwaysOriginal` keeps the chevron black under the app-wide SwiftUI tint.
        let symbol = UIImage.SymbolConfiguration(pointSize: 20, weight: .semibold)
        guard let chevron = UIImage(systemName: "chevron.left", withConfiguration: symbol)?
            .withTintColor(UIColor(Color.ink), renderingMode: .alwaysOriginal) else { return }

        let standard = UINavigationBarAppearance()
        standard.configureWithDefaultBackground()
        standard.setBackIndicatorImage(chevron, transitionMaskImage: chevron)
        let scrollEdge = UINavigationBarAppearance()
        scrollEdge.configureWithTransparentBackground()
        scrollEdge.setBackIndicatorImage(chevron, transitionMaskImage: chevron)

        let bar = UINavigationBar.appearance()
        bar.standardAppearance = standard
        bar.compactAppearance = standard
        bar.scrollEdgeAppearance = scrollEdge
    }
}

extension View {
    /// Drops the back button's title on pages pushed before iOS 26.
    @ViewBuilder
    func iconOnlyBackButton() -> some View {
        if #available(iOS 26.0, *) {
            self
        } else {
            toolbarRole(.editor)
        }
    }
}
