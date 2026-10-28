import SwiftUI

// System San Francisco with Dynamic Type; identity comes from weight, not a rounded face.
enum Typography {
    static let display = Font.system(.largeTitle, weight: .heavy)
    static let screenTitle = Font.system(.title2, weight: .bold)
    static let headerTitle = Font.system(.title2, weight: .bold)
    static let challengeTerm = Font.system(.title, weight: .heavy)
    static let sentence = Font.system(.title2, weight: .bold)
    static let body = Font.system(.body)
    static let emphasis = Font.system(.body, weight: .bold)
    static let secondary = Font.system(.subheadline)
    static let micro = Font.system(.caption)
    static let eyebrow = Font.system(.caption, weight: .bold)
    static let tile = Font.system(.body, weight: .semibold)
    static let action = Font.system(.headline, weight: .bold)
    static let wordmark = Font.system(.title3, weight: .heavy)

    static let tightTracking: CGFloat = -0.6
    static let eyebrowTracking: CGFloat = 1.2
}
