import SwiftUI

extension ChallengeNodeRef: Identifiable {
    var id: String { "\(chapterNo)-\(levelNo)" }
}

/// One to three stars, filled up to `filled`. Spoken as "2 of 3 stars". Achievements only, never a skill check.
struct StarRow: View {
    let filled: Int
    var total = ChallengeLevel.maxStars
    var size: CGFloat = 16

    var body: some View {
        HStack(spacing: size * 0.2) {
            ForEach(0..<total, id: \.self) { index in
                Image(systemName: index < filled ? "star.fill" : "star")
                    .font(.system(size: size, weight: .bold))
                    .foregroundStyle(index < filled ? Color.reward : Color.stroke)
                    // A darker keyline so a filled star doesn't rest on yellow alone.
                    .shadow(color: index < filled ? Color.rewardDepth : .clear, radius: 0, y: 1)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("\(filled) of \(total) stars"))
    }
}

/// "1:23": minutes and seconds, rounded up so the clock reads 0:00 only when time is over.
enum ChallengeTimeFormat {
    static func countdown(_ milliseconds: Int) -> String {
        let seconds = Int((Double(max(milliseconds, 0)) / 1000).rounded(.up))
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
    }

    /// "42.3 s" for results.
    static func elapsed(_ milliseconds: Int) -> String {
        (Double(milliseconds) / 1000).formatted(.number.precision(.fractionLength(1)).locale(AppLanguage.active.locale))
    }
}

/// A word or meaning tile on the Match Madness board. Looks and presses like a choice tile (`ChoiceTileButton`).
/// State never rests on colour alone: selected tiles get a thick outline, a wrong pair shakes and is announced.
struct MatchMadnessTile: View {
    enum Side { case word, meaning }

    let text: String
    let side: Side
    let isSelected: Bool
    let isWrong: Bool
    var isCorrect = false
    var minHeight: CGFloat = Spacing.matchTileMinHeight
    let shakes: Int
    let action: () -> Void
    @Environment(\.motion) private var motion
    @State private var bounce = 0

    var body: some View {
        Button {
            if !motion.reduceMotion { bounce += 1 }
            action()
        } label: {
            EmptyView()
        }
        // A quick tap inside a ScrollView often never reports isPressed, so the tile also sinks on tap.
        .buttonStyle(MatchTilePressStyle(text: text, state: state, minHeight: minHeight, bounce: bounce))
        .allowsHitTesting(!isCorrect)
        .modifier(ShakeEffect(animatableData: CGFloat(shakes)))
        .animation(motion.travel(MotionTokens.matchShake), value: shakes)
        .accessibilityLabel(side == .word ? Text("Word: \(text)") : Text("Meaning: \(text)"))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var state: WordTileVisualState {
        if isCorrect { return .correct }
        if isWrong { return .incorrect }
        return isSelected ? .selected : .idle
    }
}

private struct MatchTilePressStyle: ButtonStyle {
    let text: String
    let state: WordTileVisualState
    let minHeight: CGFloat
    let bounce: Int

    func makeBody(configuration: Configuration) -> some View {
        let canPress = state == .idle || state == .selected
        WordTile(
            text: text,
            visualState: configuration.isPressed && canPress ? .pressed : state,
            minHeight: minHeight,
            bounceTrigger: bounce,
            font: Typography.choice
        )
    }
}

struct StarRules: View {
    let criteria: ChallengeStarCriteria
    let timeLimitMs: Int

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            row(stars: 1, Text("Clear within \(timeLimitMs / 1000) seconds"))
            row(stars: 2, Text("Within \(criteria.two.maxElapsedMs / 1000) seconds and at most \(criteria.two.maxMistakes) mistakes"))
            row(stars: 3, Text("Within \(criteria.three.maxElapsedMs / 1000) seconds and at most \(criteria.three.maxMistakes) mistakes"))
        }
        .padding(Spacing.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardSurface(radius: Radii.tile, fill: .quietSurface)
    }

    private func row(stars: Int, _ text: Text) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: Spacing.s) {
            StarRow(filled: stars, size: 11)
            text
                .font(Typography.secondary)
                .foregroundStyle(Color.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }
}
