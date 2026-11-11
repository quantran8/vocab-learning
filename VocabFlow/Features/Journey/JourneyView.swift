import SwiftUI
import UIKit

/// The continuous Journey: every segment is seven learning sessions and one review, scrolled vertically with
/// the future above and history below. Nodes sit on one snake path (`JourneySnakeLayout`); the stretch already
/// travelled is coloured up to the current node.
/// The server decides each node's state; this screen only draws it and starts the current step.
struct JourneyView: View {
    @Environment(LearnerStore.self) private var learner
    @Environment(PracticeSessionStore.self) private var practice
    @Environment(\.motion) private var motion

    @State private var focusVisible = true
    @State private var hasScrolledToFocus = false
    @State private var hint: Hint?
    @State private var shownResult: ShownResult?

    private struct Hint: Equatable {
        enum Kind {
            case locked, sessionDone, reviewDone

            var text: LocalizedStringKey {
                switch self {
                case .locked: "Complete the previous step to unlock"
                case .sessionDone: "Session completed"
                case .reviewDone: "Review completed"
                }
            }

            /// VoiceOver hears the hint too; the bubble alone would be silent.
            var announcement: String {
                switch self {
                case .locked: String(localized: "Complete the previous step to unlock", bundle: .appLanguage)
                case .sessionDone: String(localized: "Session completed", bundle: .appLanguage)
                case .reviewDone: String(localized: "Review completed", bundle: .appLanguage)
                }
            }
        }

        let nodeID: String
        let kind: Kind
        let token = UUID()

        static func == (lhs: Hint, rhs: Hint) -> Bool { lhs.token == rhs.token }
    }

    private struct ShownResult: Identifiable {
        let segmentNo: Int
        let result: ReviewResult
        var id: Int { segmentNo }
    }

    private static let scrollSpace = "journey"

    var body: some View {
        GeometryReader { viewport in
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 0) {
                        header
                            .padding(.top, Spacing.xl)
                            .padding(.bottom, Spacing.l)

                        if let error = learner.journeyError, learner.journey != nil {
                            errorBanner(error)
                        }

                        if let journey = learner.journey {
                            mapView(journey.segments, anchor: journey.currentSegmentNo, focusID: journey.focusNodeId, viewport: viewport.size)
                            if journey.hasMoreHistory {
                                ProgressView()
                                    .padding(.vertical, Spacing.l)
                                    .task { await learner.loadOlderJourney() }
                            }
                        } else if let error = learner.journeyError {
                            StatusScreen(title: "Couldn’t load your journey", message: Text(verbatim: error)) {
                                SecondaryButton(title: "Try again") { Task { await learner.refreshJourney() } }
                            }
                            .frame(height: viewport.size.height * 0.6)
                        } else {
                            // A fixed placeholder; it never guesses a completed state.
                            mapView([.placeholder(sessions: learner.home?.checkpointSessionsRequired ?? 7)], anchor: nil, focusID: nil, viewport: viewport.size)
                                .redacted(reason: .placeholder)
                                .allowsHitTesting(false)
                        }
                    }
                    .padding(.horizontal, Spacing.screenGutter)
                    .padding(.bottom, Spacing.xl)
                }
                .coordinateSpace(name: Self.scrollSpace)
                .refreshable { await learner.refreshJourney() }
                .overlay(alignment: .bottom) {
                    if !focusVisible, learner.journey != nil {
                        backToCurrent(proxy)
                            .padding(.bottom, Spacing.m)
                            .transition(motion.popTransition)
                    }
                }
                .onChange(of: learner.journey?.focusNodeId, initial: true) { _, focusID in
                    guard let focusID else { return }
                    // The first jump is instant, so the learner never sees the list run from the top.
                    if hasScrolledToFocus {
                        withAnimation(motion.travel(MotionTokens.transition)) { proxy.scrollTo(focusID, anchor: .center) }
                    } else {
                        hasScrolledToFocus = true
                        Task { @MainActor in proxy.scrollTo(focusID, anchor: .center) }
                    }
                }
            }
        }
        .background(Color.canvas)
        .task { await learner.refreshJourney() }
        .sheet(item: $shownResult) { shown in
            ReviewResultSheet(segmentNo: shown.segmentNo, result: shown.result)
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
                .presentationBackground(Color.canvas)
        }
    }

    // MARK: Header

    private var header: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            PunctuatedTitle(text: "Journey")
                .accessibilityAddTraits(.isHeader)
            if let segment = learner.journey?.currentSegment {
                Text("Segment \(segment.segmentNo) · \(segment.completedLearningCount) of \(segment.sessionCount) sessions")
                    .font(Typography.secondary)
                    .foregroundStyle(Color.mutedInk)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func errorBanner(_ message: String) -> some View {
        HStack(spacing: Spacing.s) {
            Text(verbatim: message)
                .font(Typography.secondary)
                .foregroundStyle(Color.errorInk)
                .frame(maxWidth: .infinity, alignment: .leading)
            Button("Retry") { Task { await learner.refreshJourney() } }
                .font(Typography.secondary.weight(.bold))
                .foregroundStyle(Color.interactive)
                .frame(minHeight: Spacing.minTouchTarget)
        }
        .padding(.horizontal, Spacing.m)
        .background(Color.errorSurface, in: RoundedRectangle(cornerRadius: Radii.tile, style: .continuous))
        .padding(.bottom, Spacing.m)
    }

    // MARK: Map

    /// One snake for every loaded segment, so the path runs on across segment boundaries.
    private func mapView(_ segments: [JourneySegment], anchor: Int?, focusID: String?, viewport: CGSize) -> some View {
        let layout = JourneySnakeLayout(segments: segments, anchorSegmentNo: anchor, width: viewport.width - Spacing.screenGutter * 2)
        return ZStack(alignment: .topLeading) {
            JourneySnakeTrack(layout: layout)

            ForEach(layout.labels) { label in
                JourneySegmentLabel(segment: label.segment)
                    .position(label.center)
            }
            ForEach(layout.nodes) { placed in
                nodeView(placed.node, isFocus: placed.id == focusID, viewport: viewport)
                    // The face, not the frame (which includes the depth edge), sits on the path.
                    .position(x: placed.center.x, y: placed.center.y + Spacing.buttonDepth / 2)
                    .zIndex(hint?.nodeID == placed.id ? 1 : 0)
            }
        }
        .frame(width: layout.size.width, height: layout.size.height)
        .frame(maxWidth: .infinity)
    }

    private func nodeView(_ node: JourneyNode, isFocus: Bool, viewport: CGSize) -> some View {
        JourneyNodeView(node: node) { tap(node) }
            .overlay(alignment: .bottom) {
                if hint?.nodeID == node.id, let hint {
                    hintBubble(hint.kind.text)
                        .fixedSize()
                        .offset(y: 34)
                        .transition(motion.popTransition)
                }
            }
            .id(node.id)
            .onGeometryChange(for: Bool.self) { proxy in
                let frame = proxy.frame(in: .named(Self.scrollSpace))
                return frame.maxY > 0 && frame.minY < viewport.height
            } action: { visible in
                guard isFocus else { return }
                motion.perform(MotionTokens.press) { focusVisible = visible }
            }
            .onDisappear {
                if isFocus { focusVisible = false }
            }
    }

    private func hintBubble(_ text: LocalizedStringKey) -> some View {
        Text(text)
            .font(Typography.micro.weight(.bold))
            .foregroundStyle(.white)
            .padding(.horizontal, Spacing.s)
            .padding(.vertical, Spacing.xs)
            .background(Color.ink, in: RoundedRectangle(cornerRadius: Radii.chip, style: .continuous))
            .allowsHitTesting(false)
    }

    private func backToCurrent(_ proxy: ScrollViewProxy) -> some View {
        Button {
            guard let focusID = learner.journey?.focusNodeId else { return }
            withAnimation(motion.travel(MotionTokens.transition)) { proxy.scrollTo(focusID, anchor: .center) }
        } label: {
            Label("Back to current", systemImage: "location.fill")
                .font(Typography.secondary.weight(.bold))
                .foregroundStyle(Color.white)
                .padding(.horizontal, Spacing.m)
                .frame(minHeight: Spacing.minTouchTarget)
                .background(Color.interactive, in: Capsule())
        }
        .buttonStyle(.plain)
    }

    // MARK: Actions

    private func tap(_ node: JourneyNode) {
        practice.haptics.selectionChanged()
        switch (node.type, node.state) {
        case (.learning, .current):
            Task { await practice.start(.daily) }
        case (.review, .current):
            Task { await practice.start(.checkpointChallenge, challengeID: node.reviewId) }
        case (.review, .completed):
            if let result = node.result {
                shownResult = ShownResult(segmentNo: node.segmentNo, result: result)
            } else {
                show(Hint(nodeID: node.id, kind: .reviewDone))
            }
        case (.learning, .completed):
            show(Hint(nodeID: node.id, kind: .sessionDone))
        case (_, .locked):
            show(Hint(nodeID: node.id, kind: .locked))
        }
    }

    private func show(_ next: Hint) {
        motion.perform(MotionTokens.feedback) { hint = next }
        UIAccessibility.post(notification: .announcement, argument: next.kind.announcement)
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(2))
            guard hint == next else { return }
            motion.perform(MotionTokens.press) { hint = nil }
        }
    }
}

/// The saved result of a finished review. Neutral: forgetting words never fails a review.
private struct ReviewResultSheet: View {
    let segmentNo: Int
    let result: ReviewResult

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.l) {
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text("Segment \(segmentNo)")
                    .font(Typography.eyebrow)
                    .tracking(Typography.eyebrowTracking)
                    .textCase(.uppercase)
                    .foregroundStyle(Color.mutedInk)
                Text("Review completed")
                    .font(Typography.screenTitle)
                    .foregroundStyle(Color.ink)
                    .accessibilityAddTraits(.isHeader)
            }
            row("Words reviewed", value: result.reviewedCount)
            row("Remembered on your own", value: result.unaidedRecalledCount)
            row("Coming back for review", value: result.needsReviewCount)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, Spacing.screenGutter)
        .padding(.top, Spacing.xl)
    }

    private func row(_ label: LocalizedStringKey, value: Int) -> some View {
        HStack {
            Text(label)
                .font(Typography.body)
                .foregroundStyle(Color.ink)
            Spacer()
            Text(value, format: .number)
                .font(Typography.emphasis.monospacedDigit())
                .foregroundStyle(Color.ink)
        }
        .padding(Spacing.m)
        .cardSurface(radius: Radii.tile)
        .accessibilityElement(children: .combine)
    }
}
