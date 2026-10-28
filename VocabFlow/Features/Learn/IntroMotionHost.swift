import SwiftUI

enum IntroMotionState: Equatable {
    /// Holding until the step transition has landed, so letters never animate while sliding in.
    case waiting
    case revealing, settled, skipped
}

/// Renders only the English spelling with one of six motion recipes, plus Replay / Show word now.
/// Owns presentation state only — never attempts, scores or session advancement.
struct IntroMotionHost<Accessory: View>: View {
    let word: String
    let presentation: IntroductionPresentation
    @ViewBuilder let accessory: Accessory

    @Environment(\.motion) private var motion
    @ScaledMetric(relativeTo: .largeTitle) private var fontSize: CGFloat = 48
    @State private var generation = 0
    @State private var state: IntroMotionState = .waiting
    @State private var naturalWidth: CGFloat = 0
    @State private var availableWidth: CGFloat = 0

    var body: some View {
        VStack(spacing: Spacing.m) {
            stage
                .frame(maxWidth: .infinity, minHeight: fontSize * 2.2)
                .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { availableWidth = $0 }

            HStack(spacing: Spacing.s) {
                if !motion.reduceMotion { replayControl }
                Spacer(minLength: 0)
                accessory
            }
        }
        .onChange(of: presentation) { replay() }
        // Decorative timing only (never gates Next). Cancelled on replay/disappear, so stale runs are ignored.
        .task(id: generation) {
            guard !motion.reduceMotion else { return }
            if state == .waiting {
                try? await Task.sleep(for: .seconds(MotionTokens.transitionDuration))
                guard !Task.isCancelled, state == .waiting else { return }
                state = .revealing
            }
            guard state == .revealing else { return }
            try? await Task.sleep(for: .seconds(presentation.revealDuration(for: word)))
            guard !Task.isCancelled, state == .revealing else { return }
            state = .settled
        }
    }

    /// A static, hidden copy of the word sizes the stage; the animation draws on top of it.
    private var stage: some View {
        Text(verbatim: word)
            .lineLimit(1)
            .fixedSize()
            .hidden()
            .overlay {
                if motion.reduceMotion || state == .skipped {
                    Text(verbatim: word).fixedSize()
                } else if state != .waiting {
                    animatedWord.id(generation)
                }
            }
            .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { naturalWidth = $0 }
            .font(.system(size: fontSize, weight: .heavy))
            .tracking(-0.5)
            .foregroundStyle(Color.ink)
            .scaleEffect(fitScale)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(verbatim: word))
            .accessibilityAddTraits(.isHeader)
    }

    /// Long words or accessibility sizes shrink to fit instead of clipping or wrapping mid-word.
    private var fitScale: CGFloat {
        guard naturalWidth > 0, availableWidth > 0 else { return 1 }
        return min(1, availableWidth / naturalWidth)
    }

    @ViewBuilder
    private var animatedWord: some View {
        switch presentation.templateID {
        case .letterCascade: LetterCascadeView(word: word)
        case .wordAssemble: WordAssembleView(word: word)
        case .letterWave: LetterWaveView(word: word)
        case .swipeReveal: SwipeRevealView(word: word)
        case .flipLetters: FlipLettersView(word: word)
        case .chunkMerge: ChunkMergeView(chunks: presentation.introChunks ?? [word])
        }
    }

    @ViewBuilder
    private var replayControl: some View {
        if state == .waiting || state == .revealing {
            Button("Show word now") { state = .skipped }
                .font(Typography.secondary.weight(.bold))
                .foregroundStyle(Color.mutedInk)
                .frame(minHeight: Spacing.minTouchTarget)
        } else {
            Button {
                replay()
            } label: {
                Label("Replay", systemImage: "arrow.counterclockwise")
            }
            .font(Typography.secondary.weight(.bold))
            .foregroundStyle(Color.selectedInk)
            .frame(minHeight: Spacing.minTouchTarget)
            .accessibilityHint(Text("Replays the word animation only."))
        }
    }

    private func replay() {
        state = .revealing
        generation += 1
    }
}

extension IntroductionPresentation {
    /// Visual motion budget per recipe (style guide §7). Never used as a navigation gate.
    func revealDuration(for word: String) -> Double {
        let glyphs = Double(word.count)
        switch templateID {
        case .letterCascade: return glyphs * MotionTokens.introLetterStagger + 0.45
        case .wordAssemble: return 0.65
        case .letterWave: return glyphs * 0.05 + 0.45
        case .swipeReveal: return 0.8
        case .flipLetters: return glyphs * 0.06 + 0.45
        case .chunkMerge:
            return Double(introChunks?.count ?? 1) * MotionTokens.introChunkStagger + MotionTokens.introChunkHold + 0.4
        }
    }
}

extension IntroductionTemplateID {
    var title: LocalizedStringKey {
        switch self {
        case .letterCascade: "Letter Cascade"
        case .wordAssemble: "Word Assemble"
        case .letterWave: "Letter Wave"
        case .swipeReveal: "Swipe Reveal"
        case .flipLetters: "Flip Letters"
        case .chunkMerge: "Chunk Merge"
        }
    }
}
