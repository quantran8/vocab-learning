import CoreGraphics

enum Spacing {
    static let xxs: CGFloat = 4
    static let xs: CGFloat = 8
    static let s: CGFloat = 12
    static let m: CGFloat = 16
    static let l: CGFloat = 24
    static let xl: CGFloat = 32

    static let screenGutter: CGFloat = 20
    static let minTouchTarget: CGFloat = 44
    static let audioButton: CGFloat = 52
    static let tileMinHeight: CGFloat = 60
    /// Sign in with Apple / Google buttons, the same height as `PrimaryButton`.
    static let socialButtonHeight: CGFloat = 52
    static let tileDepth: CGFloat = 3
    static let buttonDepth: CGFloat = 4
    static let dropHitInset: CGFloat = 12
    static let slotMinWidth: CGFloat = 132
}
