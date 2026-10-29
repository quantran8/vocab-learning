import SwiftUI

// Color Pop palette — see vocab-flow-color-pop-style-guide.md §2.
extension Color {
    // Core palette
    static let canvas = Color(hex: 0xFFFFFF)
    static let surface = Color(hex: 0xFFFFFF)
    static let ink = Color(hex: 0x171717)
    static let mutedInk = Color(hex: 0x5C606B)
    static let primaryAction = Color(hex: 0x0B0C0E)
    static let interactive = Color(hex: 0x4775F5)
    static let reward = Color(hex: 0xFFD23F)
    static let success = Color(hex: 0x2BC86A)
    static let error = Color(hex: 0xFF795D)
    static let neutralSurface = Color(hex: 0xF5F5F5)
    static let stroke = Color(hex: 0xE1E4EB)

    // State support
    static let selectedSurface = Color(hex: 0xEAF0FF)
    static let selectedInk = Color(hex: 0x234EAE)
    static let successSurface = Color(hex: 0xE5FAED)
    static let successInk = Color(hex: 0x12673A)
    static let errorSurface = Color(hex: 0xFFF0EA)
    static let errorInk = Color(hex: 0x943727)
    static let focusRing = Color(hex: 0x4775F5)
    static let disabledSurface = Color(hex: 0xF1F2F4)
    static let disabledInk = Color(hex: 0x707783)
    static let quietSurface = Color(hex: 0xFAFAFA)

    // Stepped depth under tactile surfaces
    static let primaryDepth = Color(hex: 0x33363D)
    static let interactiveDepth = Color(hex: 0x2B55CE)
    static let rewardDepth = Color(hex: 0xB89528)
    static let tileDepth = Color(hex: 0xE1E4EB)
    static let selectedDepth = Color(hex: 0xC4D3FC)
    static let successDepth = Color(hex: 0xB7EDCB)
    static let errorDepth = Color(hex: 0xFFD2C6)

    static let track = Color(hex: 0xE1E4EB)
    static let slotTargetedSurface = Color(hex: 0xD9E4FF)
    static let dot = Color(hex: 0xE1E4EB)

    init(hex: UInt32) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}
