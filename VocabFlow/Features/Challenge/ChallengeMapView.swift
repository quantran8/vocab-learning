import SwiftUI

/// The Challenge Map: chapters of three Match Madness levels, oldest at the top, the next chapter's preview at the
/// bottom. It replaces the Journey. Every state comes from the server; stars are achievements, not skill checks.
struct ChallengeMapView: View {
    @Environment(ChallengeMapStore.self) private var store
    @Environment(ChallengeRunStore.self) private var run
    @Environment(PracticeSessionStore.self) private var practice
    @Environment(\.motion) private var motion
    @State private var selected: ChallengeNodeRef?
    @State private var didScrollToCurrent = false

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.xl) {
                    header

                    if let error = store.error {
                        ErrorBanner(text: error) {
                            Task { await store.refresh() }
                        }
                    }

                    if let map = store.map {
                        ForEach(Array(map.chapters.enumerated()), id: \.element.id) { index, chapter in
                            ChallengeChapterSection(
                                chapter: chapter,
                                waveStart: ChallengeMapWave.start(ofChapterAt: index, in: map),
                                currentNode: map.currentNode,
                                onSelect: { selected = $0 }
                            )
                        }
                        if let next = map.nextChapter {
                            NextChapterSection(
                                preview: next,
                                waveStart: ChallengeMapWave.start(ofChapterAt: map.chapters.count, in: map),
                                onPlay: { play(ChallengeNodeRef(chapterNo: next.chapterNo, levelNo: 1), level: nil) },
                                onLearn: { Task { await practice.start(.daily) } }
                            )
                            .id(ChallengeMapAnchor.next)
                        }
                    } else if store.isLoading || store.error == nil {
                        ProgressView()
                            .controlSize(.large)
                            .frame(maxWidth: .infinity)
                            .padding(.top, Spacing.xl)
                    }
                }
                .padding(.horizontal, Spacing.screenGutter)
                .padding(.top, Spacing.m)
                .padding(.bottom, Spacing.xl)
            }
            .refreshable { await store.refresh() }
            .onChange(of: store.map?.currentNode, initial: true) { _, node in
                // Once per visit: a refresh after a run keeps the learner's scroll position.
                guard !didScrollToCurrent, store.map != nil else { return }
                didScrollToCurrent = true
                let target = node.map(ChallengeMapAnchor.node) ?? .next
                Task { @MainActor in
                    proxy.scrollTo(target, anchor: .center)
                }
            }
        }
        .background(Color.canvas)
        .task { await store.refresh() }
        .sheet(item: $selected) { node in
            ChallengeLevelSheet(
                node: node,
                chapter: store.chapter(node.chapterNo),
                level: store.level(node),
                onPlay: { play(node, level: store.level(node)) },
                onPracticeUntimed: { startUntimed() }
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
            .presentationBackground(Color.canvas)
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            PunctuatedTitle(text: "Challenge")
            Spacer(minLength: Spacing.s)
            if let map = store.map, !map.chapters.isEmpty {
                HStack(spacing: Spacing.xxs) {
                    Image(systemName: "star.fill")
                        .foregroundStyle(Color.reward)
                        .accessibilityHidden(true)
                    Text(verbatim: "\(map.totalStars)")
                        .font(Typography.emphasis.monospacedDigit())
                        .foregroundStyle(Color.ink)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text("\(map.totalStars) stars in total"))
            }
        }
    }

    private func play(_ node: ChallengeNodeRef, level: ChallengeLevel?) {
        selected = nil
        Task { await run.play(node, level: level) }
    }

    private func startUntimed() {
        selected = nil
        run.startSandbox(plan: .sandbox(), timed: false)
    }
}

enum ChallengeMapAnchor: Hashable {
    case node(ChallengeNodeRef)
    case next
}

private struct ErrorBanner: View {
    let text: String
    let onRetry: () -> Void

    var body: some View {
        HStack(spacing: Spacing.s) {
            Text(verbatim: text)
                .font(Typography.secondary)
                .foregroundStyle(Color.errorInk)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            Button("Retry", action: onRetry)
                .font(Typography.secondary.weight(.bold))
                .foregroundStyle(Color.interactive)
                .frame(minHeight: Spacing.minTouchTarget)
        }
        .padding(.horizontal, Spacing.m)
        .cardSurface(radius: Radii.tile, fill: .errorSurface)
    }
}

// MARK: - Path

/// Where each stop sits on the winding path. The wave runs on across chapters (levels plus the chapter's trophy), so
/// the whole map reads as one road.
enum ChallengeMapWave {
    private static let offsets: [CGFloat] = [0, 0.55, 1, 0.55, 0, -0.55, -1, -0.55]
    private static let amplitude: CGFloat = 78
    /// Levels shown for a chapter the server hasn't materialized yet.
    static let previewLevelCount = 3

    static func offset(at index: Int) -> CGFloat {
        offsets[index % offsets.count] * amplitude
    }

    static func start(ofChapterAt index: Int, in map: ChallengeMap) -> Int {
        map.chapters.prefix(index).reduce(0) { $0 + $1.levels.count + 1 }
    }
}

// MARK: - Chapter

/// One chapter: a banner, then its levels and a trophy along the path. Cleared levels stay replayable.
struct ChallengeChapterSection: View {
    let chapter: ChallengeChapter
    let waveStart: Int
    let currentNode: ChallengeNodeRef?
    let onSelect: (ChallengeNodeRef) -> Void

    var body: some View {
        VStack(spacing: Spacing.l) {
            ChapterBanner(
                chapterNo: chapter.chapterNo,
                status: statusLabel,
                style: bannerStyle,
                stars: (chapter.starsEarned, chapter.maxStars)
            )
            VStack(spacing: Spacing.l) {
                ForEach(Array(chapter.levels.enumerated()), id: \.element.id) { index, level in
                    let node = ChallengeNodeRef(chapterNo: chapter.chapterNo, levelNo: level.levelNo)
                    ChallengeLevelNode(level: level, node: node, isCurrent: node == currentNode) {
                        onSelect(node)
                    }
                    .offset(x: ChallengeMapWave.offset(at: waveStart + index))
                    .id(ChallengeMapAnchor.node(node))
                }
                ChapterTrophy(isEarned: chapter.state == .completed)
                    .offset(x: ChallengeMapWave.offset(at: waveStart + chapter.levels.count))
            }
            .frame(maxWidth: .infinity)
        }
    }

    private var statusLabel: LocalizedStringKey {
        switch chapter.state {
        case .completed: "Cleared"
        case .contentUnavailable: "Learn more words to keep playing"
        case .active, .unknown: "In progress"
        }
    }

    private var bannerStyle: ChapterBannerStyle {
        switch chapter.state {
        case .completed: .completed
        case .contentUnavailable: .muted
        case .active, .unknown: .active
        }
    }
}

/// The full-width header that opens a chapter on the path, with an optional detail (e.g. how to unlock it) inside.
private struct ChapterBanner<Detail: View>: View {
    let chapterNo: Int
    let status: LocalizedStringKey
    let style: ChapterBannerStyle
    var stars: (earned: Int, max: Int)?
    let detail: Detail

    init(
        chapterNo: Int,
        status: LocalizedStringKey,
        style: ChapterBannerStyle,
        stars: (earned: Int, max: Int)? = nil,
        @ViewBuilder detail: () -> Detail
    ) {
        self.chapterNo = chapterNo
        self.status = status
        self.style = style
        self.stars = stars
        self.detail = detail()
    }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: Radii.card, style: .continuous)
        VStack(alignment: .leading, spacing: Spacing.m) {
            title
            detail
        }
        .padding(Spacing.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(fill, in: shape)
        .background(shape.fill(depth).offset(y: Spacing.buttonDepth))
        .padding(.bottom, Spacing.buttonDepth)
    }

    private var title: some View {
        HStack(spacing: Spacing.s) {
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text("Chapter \(chapterNo)")
                    .font(Typography.eyebrow)
                    .tracking(Typography.eyebrowTracking)
                    .textCase(.uppercase)
                    .foregroundStyle(ink.opacity(0.75))
                Text(status)
                    .font(Typography.tileLarge.weight(.bold))
                    .foregroundStyle(ink)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            if let stars {
                HStack(spacing: Spacing.xxs) {
                    Image(systemName: "star.fill")
                        .foregroundStyle(Color.reward)
                        .shadow(color: .rewardDepth, radius: 0, y: 1)
                    Text(verbatim: "\(stars.earned) / \(stars.max)")
                        .font(Typography.secondary.weight(.bold).monospacedDigit())
                        .foregroundStyle(Color.ink)
                }
                .padding(.horizontal, Spacing.s)
                .padding(.vertical, Spacing.xs)
                .background(Color.surface, in: Capsule())
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text("\(stars.earned) of \(stars.max) stars"))
            } else if style == .muted {
                Image(systemName: "lock.fill")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(Color.disabledInk)
                    .accessibilityHidden(true)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }

    private var fill: Color {
        switch style {
        case .active: .interactive
        case .completed: .reward
        case .muted: .disabledSurface
        }
    }

    private var depth: Color {
        switch style {
        case .active: .interactiveDepth
        case .completed: .rewardDepth
        case .muted: .tileDepth
        }
    }

    private var ink: Color {
        style == .active ? .white : .ink
    }
}

private enum ChapterBannerStyle { case active, completed, muted }

extension ChapterBanner where Detail == EmptyView {
    init(chapterNo: Int, status: LocalizedStringKey, style: ChapterBannerStyle, stars: (earned: Int, max: Int)? = nil) {
        self.init(chapterNo: chapterNo, status: status, style: style, stars: stars) { EmptyView() }
    }
}

/// One level: a raised round button with a glyph for its state (lock, play, check) and its best stars underneath.
/// The current level wears a ring and a bobbing "Start" callout.
private struct ChallengeLevelNode: View {
    static let size: CGFloat = 72
    static let depth: CGFloat = 7

    let level: ChallengeLevel
    let node: ChallengeNodeRef
    let isCurrent: Bool
    /// Nil for a level that can't be opened yet (a chapter the server hasn't materialized).
    let action: (() -> Void)?
    @Environment(ChallengeMapStore.self) private var store
    @Environment(\.motion) private var motion
    @State private var unlockScale: CGFloat = 1

    var body: some View {
        VStack(spacing: Spacing.xs) {
            Button {
                action?()
            } label: {
                glyph
                    .frame(width: Self.size, height: Self.size)
                    .background {
                        if isCurrent {
                            Circle()
                                .strokeBorder(Color.interactive.opacity(0.3), lineWidth: 5)
                                .padding(-10)
                                .offset(y: Self.depth / 2)
                        }
                    }
            }
            .buttonStyle(MapNodeButtonStyle(face: face, depth: depth))
            .disabled(action == nil)
            .overlay(alignment: .top) {
                if isCurrent {
                    StartCallout()
                        .alignmentGuide(.top) { $0[.bottom] + Spacing.m }
                }
            }
            .scaleEffect(unlockScale)

            if level.state == .cleared {
                StarRow(filled: level.bestStars, size: 14)
            }
        }
        .padding(.top, isCurrent ? Spacing.xl + Spacing.s : 0)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(accessibilityLabel))
        .accessibilityAddTraits(.isButton)
        .onAppear {
            // Plays once, after the server confirmed the unlock.
            guard store.newlyUnlocked.contains(node) else { return }
            store.consumeUnlock(node)
            guard !motion.reduceMotion else { return }
            unlockScale = 0.6
            motion.perform(MotionTokens.entrance) { unlockScale = 1 }
        }
    }

    @ViewBuilder
    private var glyph: some View {
        switch level.state {
        case .locked, .unknown:
            Image(systemName: "lock.fill")
                .font(.system(size: 26, weight: .bold))
                .foregroundStyle(Color.disabledInk)
        case .available:
            Image(systemName: "play.fill")
                .font(.system(size: 28, weight: .black))
                .foregroundStyle(.white)
        case .cleared:
            Image(systemName: "checkmark")
                .font(.system(size: 28, weight: .black))
                .foregroundStyle(.white)
                .shadow(color: .rewardDepth, radius: 0, y: 2)
        }
    }

    private var face: Color {
        switch level.state {
        case .locked, .unknown: .disabledSurface
        case .available: .interactive
        case .cleared: .reward
        }
    }

    private var depth: Color {
        switch level.state {
        case .locked, .unknown: .tileDepth
        case .available: .interactiveDepth
        case .cleared: .rewardDepth
        }
    }

    private var accessibilityLabel: LocalizedStringKey {
        switch level.state {
        case .locked, .unknown: "Level \(level.levelNo), locked"
        case .available: "Level \(level.levelNo), ready to play"
        case .cleared: "Level \(level.levelNo), cleared, \(level.bestStars) of 3 stars"
        }
    }
}

/// Pressing sinks the face onto its depth, like a key.
private struct MapNodeButtonStyle: ButtonStyle {
    let face: Color
    let depth: Color
    @Environment(\.motion) private var motion

    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed
        configuration.label
            .background(face, in: Circle())
            .offset(y: pressed ? ChallengeLevelNode.depth - 1 : 0)
            .background(Circle().fill(depth).offset(y: ChallengeLevelNode.depth))
            .padding(.bottom, ChallengeLevelNode.depth)
            .contentShape(Circle())
            .animation(motion.animation(MotionTokens.press), value: pressed)
    }
}

private struct StartCallout: View {
    @Environment(\.motion) private var motion
    @State private var isRaised = false

    var body: some View {
        Text("Start")
            .font(Typography.eyebrow)
            .tracking(Typography.eyebrowTracking)
            .textCase(.uppercase)
            .foregroundStyle(Color.interactive)
            .fixedSize()
            .padding(.horizontal, Spacing.s)
            .padding(.top, Spacing.xs)
            .padding(.bottom, Spacing.xs + CalloutShape.tail)
            .background(CalloutShape().fill(Color.surface))
            .overlay(CalloutShape().stroke(Color.stroke, lineWidth: 2))
            .offset(y: isRaised ? -Spacing.xxs - 1 : 0)
            .onAppear {
                guard !motion.reduceMotion else { return }
                motion.perform(MotionTokens.mapCalloutBob) { isRaised = true }
            }
            .accessibilityHidden(true)
    }
}

/// A rounded box with a tail pointing down at its centre.
private struct CalloutShape: Shape {
    static let tail: CGFloat = 8

    func path(in rect: CGRect) -> Path {
        let box = CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: rect.height - Self.tail)
        var tail = Path()
        tail.move(to: CGPoint(x: rect.midX - Self.tail, y: box.maxY - 1))
        tail.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        tail.addLine(to: CGPoint(x: rect.midX + Self.tail, y: box.maxY - 1))
        tail.closeSubpath()
        return Path(roundedRect: box, cornerRadius: Radii.chip, style: .continuous).union(tail)
    }
}

/// The chapter's last stop: gold once every level is cleared. Decoration only; the banner states it.
private struct ChapterTrophy: View {
    private static let size: CGFloat = 64

    let isEarned: Bool

    var body: some View {
        Image(systemName: "trophy.fill")
            .font(.system(size: 28, weight: .bold))
            .foregroundStyle(isEarned ? Color.white : Color.disabledInk)
            .shadow(color: isEarned ? .rewardDepth : .clear, radius: 0, y: 2)
            .frame(width: Self.size, height: Self.size)
            .background(isEarned ? Color.reward : Color.disabledSurface, in: Circle())
            .background(Circle().fill(isEarned ? Color.rewardDepth : Color.tileDepth).offset(y: ChallengeLevelNode.depth))
            .padding(.bottom, ChallengeLevelNode.depth)
            .accessibilityHidden(true)
    }
}

// MARK: - Next chapter

/// The chapter after the last one, on the same path: locked with a word count until enough eligible words are
/// learned in Daily, then ready. It gets a permanent ID only when its first run is issued.
private struct NextChapterSection: View {
    let preview: ChallengeChapterPreview
    let waveStart: Int
    let onPlay: () -> Void
    let onLearn: () -> Void

    private var isReady: Bool { preview.state == .ready }

    var body: some View {
        VStack(spacing: Spacing.l) {
            ChapterBanner(
                chapterNo: preview.chapterNo,
                status: isReady ? "Ready to play" : "Locked",
                style: isReady ? .active : .muted
            ) {
                if !isReady {
                    unlockCondition
                }
            }
            VStack(spacing: Spacing.l) {
                ForEach(1...ChallengeMapWave.previewLevelCount, id: \.self) { levelNo in
                    let playable = isReady && levelNo == 1
                    ChallengeLevelNode(
                        level: ChallengeLevel(levelNo: levelNo, state: playable ? .available : .locked, bestStars: 0, bestScore: 0),
                        node: ChallengeNodeRef(chapterNo: preview.chapterNo, levelNo: levelNo),
                        isCurrent: playable,
                        action: playable ? onPlay : nil
                    )
                    .offset(x: ChallengeMapWave.offset(at: waveStart + levelNo - 1))
                }
                ChapterTrophy(isEarned: false)
                    .offset(x: ChallengeMapWave.offset(at: waveStart + ChallengeMapWave.previewLevelCount))
            }
            .frame(maxWidth: .infinity)
        }
    }

    @ViewBuilder
    private var unlockCondition: some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            switch preview.state {
            case .locked:
                Text("Clear Chapter \(preview.chapterNo - 1) to unlock this chapter.")
                    .font(Typography.secondary)
                    .foregroundStyle(Color.mutedInk)
                    .fixedSize(horizontal: false, vertical: true)
            case .needsVocabulary, .unknown, .ready:
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text("\(preview.eligibleNewCount) / \(preview.requiredNewCount) new words")
                        .font(Typography.secondary.weight(.bold).monospacedDigit())
                        .foregroundStyle(Color.ink)
                    ProgressTrack(fraction: preview.requiredNewCount > 0
                        ? min(CGFloat(preview.eligibleNewCount) / CGFloat(preview.requiredNewCount), 1) : 0)
                        .accessibilityHidden(true)
                }
                .accessibilityElement(children: .combine)
                Text("Learn new words in your Daily Lesson to unlock this chapter. Some words can’t be used in a challenge, so this count can differ from My Words.")
                    .font(Typography.secondary)
                    .foregroundStyle(Color.mutedInk)
                    .fixedSize(horizontal: false, vertical: true)
                SecondaryButton(title: "Continue Daily", action: onLearn)
            }
        }
    }
}
