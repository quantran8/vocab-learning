import SwiftUI

extension Color {
    static let canvas = Color(hex: 0xF7F7F2)
    static let surface = Color(hex: 0xFFFFFF)
    static let ink = Color(hex: 0x242536)
    static let mutedInk = Color(hex: 0x696977)

    static let primaryAction = Color(hex: 0x705CF6)
    static let primaryDepth = Color(hex: 0x5140C9)
    static let primarySoft = Color(hex: 0xEBE7FF)
    static let primarySoftInk = Color(hex: 0x5A47C8)

    static let selectedSurface = Color(hex: 0xEFECFF)
    static let selectedDepth = Color(hex: 0xDED8FF)
    static let successSurface = Color(hex: 0xE5F8EF)
    static let successInk = Color(hex: 0x147E60)
    static let successDepth = Color(hex: 0xBFE9D8)
    static let errorSurface = Color(hex: 0xFFF0EB)
    static let errorInk = Color(hex: 0xA64734)
    static let errorDepth = Color(hex: 0xF6D3C9)

    static let stroke = Color(hex: 0xE6E4E0)
    static let tileDepth = Color(hex: 0xEAE8E5)
    static let track = Color(hex: 0xE7E5E0)
    static let slotSurface = Color(hex: 0xF1EFFC)
    static let slotStroke = Color(hex: 0xC5BBFC)
    static let slotTargetedStroke = Color(hex: 0x9C8EFB)
    static let inputStroke = Color(hex: 0xE5E2E9)
    static let inputFocus = Color(hex: 0xAA99FA)
    static let disabledFace = Color(hex: 0xC7C3DF)
    static let disabledDepth = Color(hex: 0xAAA7C0)
    static let dot = Color(hex: 0xDBD8D1)

    static let mint = Color(hex: 0x41C6A4)
    static let coral = Color(hex: 0xFF8C78)

    init(hex: UInt32) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}
