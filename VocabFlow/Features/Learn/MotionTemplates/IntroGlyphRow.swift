import SwiftUI

/// Transform of one grapheme before it settles. The rest state is always the identity.
struct IntroGlyphStyle {
    var offset: CGSize = .zero
    var scale: CGFloat = 1
    var opacity: Double = 1
    var rotationX: Double = 0

    static let rest = IntroGlyphStyle()
}

/// Renders a word as per-grapheme `Text` views (Character = grapheme cluster, never UTF-16 units).
/// Each glyph animates from `hidden(index)` to rest with its own staggered animation.
struct IntroGlyphRow: View {
    let word: String
    let isRevealed: Bool
    let hidden: (_ index: Int, _ count: Int) -> IntroGlyphStyle
    let animation: (_ index: Int) -> Animation

    var body: some View {
        let glyphs = Array(word)
        HStack(spacing: 0) {
            ForEach(Array(glyphs.enumerated()), id: \.offset) { index, glyph in
                let style = isRevealed ? IntroGlyphStyle.rest : hidden(index, glyphs.count)
                Text(String(glyph))
                    .opacity(style.opacity)
                    .scaleEffect(style.scale)
                    .rotation3DEffect(.degrees(style.rotationX), axis: (x: 1, y: 0, z: 0), perspective: 0.5)
                    .offset(style.offset)
                    .animation(animation(index), value: isRevealed)
            }
        }
        .fixedSize()
    }
}
