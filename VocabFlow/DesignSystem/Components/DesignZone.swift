import SwiftUI

/// Which half of the design system a screen belongs to. Set per route in `AppRootView`.
enum DesignZone {
    /// Answering, or the end of answering: tactile surfaces with a thick edge.
    case lesson
    /// Everything else: flat, calm surfaces.
    case product
}

private struct DesignZoneKey: EnvironmentKey {
    static let defaultValue = DesignZone.lesson
}

extension EnvironmentValues {
    var designZone: DesignZone {
        get { self[DesignZoneKey.self] }
        set { self[DesignZoneKey.self] = newValue }
    }
}
