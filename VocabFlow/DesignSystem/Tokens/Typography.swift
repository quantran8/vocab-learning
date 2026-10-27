import SwiftUI

enum Typography {
    static let display = Font.system(.largeTitle, design: .rounded, weight: .heavy)
    static let screenTitle = Font.system(.title, design: .rounded, weight: .heavy)
    static let headerTitle = Font.system(.title2, design: .rounded, weight: .bold)
    static let challengeTerm = Font.system(.title, design: .rounded, weight: .bold)
    static let sentence = Font.system(.title2, design: .rounded, weight: .heavy)
    static let body = Font.system(.body, design: .rounded)
    static let emphasis = Font.system(.body, design: .rounded, weight: .bold)
    static let secondary = Font.system(.subheadline, design: .rounded)
    static let micro = Font.system(.caption, design: .rounded)
    static let eyebrow = Font.system(.caption, design: .rounded, weight: .heavy)
    static let tile = Font.system(.headline, design: .rounded, weight: .heavy)
    static let action = Font.system(.headline, design: .rounded, weight: .bold)
    static let wordmark = Font.system(.title3, design: .rounded, weight: .heavy)

    static let tightTracking: CGFloat = -1
    static let eyebrowTracking: CGFloat = 1.6
}
