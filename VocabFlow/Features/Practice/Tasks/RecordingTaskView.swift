import SwiftUI

/// Read aloud, get scored, optionally read again. The last assessment is what gets committed.
struct RecordingTaskView: View {
    let attempt: TaskAttempt
    @Environment(PracticeSessionStore.self) private var store

    var body: some View {
        TaskScaffold(attempt: attempt) {
            VStack(spacing: Spacing.m) {
                micButton
                status
            }
            .frame(maxWidth: .infinity)
        } action: {
            VStack(spacing: Spacing.s) {
                actions
            }
        }
    }

    private var isRecording: Bool { store.recording == .recording }

    private var micButton: some View {
        RecordingPulseButton(isRecording: isRecording, isEnabled: canUseMic, level: store.inputLevel) {
            Task {
                if isRecording {
                    await store.stopRecording()
                } else {
                    await store.startRecording()
                }
            }
        }
    }

    private var canUseMic: Bool {
        switch store.recording {
        case .uploading, .blocked: false
        case .recording: true
        default: attempt.canRecordAgain
        }
    }

    @ViewBuilder
    private var status: some View {
        switch store.recording {
        case .idle:
            statusText("Tap the microphone and read aloud.")
        case .recording:
            VStack(spacing: Spacing.s) {
                ListeningBars(level: store.inputLevel)
                statusText("Listening… tap to stop.")
            }
        case .uploading:
            ProgressView()
        case .assessed(let assessment):
            result(assessment)
        case .uploadFailed:
            statusText("Couldn’t check your recording.")
        case .blocked(let reason):
            statusText(reason == PracticeSessionStore.UnavailableReason.micDenied
                ? "Microphone access is off. You can turn it on in Settings."
                : "Recording isn’t available right now.")
        }
    }

    @ViewBuilder
    private func result(_ assessment: RecordingAssessment) -> some View {
        if !assessment.isValid {
            statusText(attempt.canRecordAgain ? "We couldn’t hear you clearly. Try reading again." : "We couldn’t hear you clearly.")
        } else {
            VStack(spacing: Spacing.xxs) {
                if let score = assessment.accuracyScore {
                    Text(score, format: .number.precision(.fractionLength(0)))
                        .font(Typography.display.monospacedDigit())
                        .foregroundStyle(assessment.passed == true ? Color.successInk : Color.errorInk)
                }
                statusText(assessment.passed == true ? "Great pronunciation!" : (attempt.canRecordAgain ? "Close. Try once more?" : "Close. Keep practicing."))
                if let heard = assessment.heard, assessment.passed != true {
                    statusText("We heard “\(heard)”")
                }
            }
            .accessibilityElement(children: .combine)
        }
    }

    private func statusText(_ text: LocalizedStringKey) -> some View {
        Text(text)
            .font(Typography.secondary)
            .foregroundStyle(Color.mutedInk)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
    }

    @ViewBuilder
    private var actions: some View {
        switch store.recording {
        case .assessed(let assessment) where assessment.isValid || !attempt.canRecordAgain:
            PrimaryButton(title: "Continue") { store.acceptRecording() }
        case .uploadFailed:
            PrimaryButton(title: "Try again") {
                Task { await store.retryUpload() }
            }
            SecondaryButton(title: "Skip") { store.acceptRecording() }
        case .blocked:
            PrimaryButton(title: "Continue") { store.acceptRecording() }
        case .idle, .assessed:
            SecondaryButton(title: "Can’t speak now") { store.acceptRecording() }
        case .recording, .uploading:
            EmptyView()
        }
    }
}

/// Record control: breathes at rest; the halo and voice ripples appear only while recording.
private struct RecordingPulseButton: View {
    let isRecording: Bool
    let isEnabled: Bool
    let level: () -> Double
    let action: () -> Void

    @Environment(\.motion) private var motion

    private static let buttonSize: CGFloat = 104
    private static let haloScales: [CGFloat] = [1.22, 1.5, 1.8]
    private static let haloSwell: CGFloat = 0.22
    private static let rippleCount = 3
    private static let ripplePeriod: Double = 1.6
    private static let breathDepth: CGFloat = 0.07
    private static let breathPeriod: Double = 3.2

    private var isLive: Bool { isRecording && !motion.reduceMotion }
    private var isBreathing: Bool { !isRecording && isEnabled && !motion.reduceMotion }

    var body: some View {
        TimelineView(.animation(paused: !isLive && !isBreathing)) { context in
            let time = context.date.timeIntervalSinceReferenceDate
            let loudness = isLive ? level() : 0
            ZStack {
                ZStack {
                    halo(swell: CGFloat(loudness))
                        .opacity(isRecording ? 1 : 0)
                        .scaleEffect(isRecording ? 1 : 0.8)
                    if isLive {
                        ripples(at: time, loudness: loudness)
                    }
                }
                .allowsHitTesting(false)
                .accessibilityHidden(true)

                recordButton
                    .scaleEffect(isBreathing ? breath(at: time) : 1)
            }
            .animation(motion.animation(MotionTokens.transition), value: isRecording)
        }
        .frame(width: Self.buttonSize * 2, height: Self.buttonSize * 2)
    }

    private func breath(at time: TimeInterval) -> CGFloat {
        1 + Self.breathDepth * CGFloat(1 - cos(time * 2 * .pi / Self.breathPeriod)) / 2
    }

    private var recordButton: some View {
        Button(action: action) {
            Image(systemName: isRecording ? "pause.fill" : "play.fill")
                .font(.system(size: 38, weight: .bold))
                .foregroundStyle(isEnabled ? Color.surface : Color.disabledInk)
                .contentTransition(.symbolEffect(.replace))
                .frame(width: Self.buttonSize, height: Self.buttonSize)
                .background(isEnabled ? Color.interactive : Color.disabledSurface, in: Circle())
                .overlay(Circle().strokeBorder(Color.surface.opacity(isEnabled ? 0.35 : 0), lineWidth: 2))
                .shadow(color: Color.interactiveDepth.opacity(isEnabled ? 0.35 : 0), radius: 16, y: 6)
                .contentShape(Circle())
        }
        .buttonStyle(PressScaleButtonStyle())
        .disabled(!isEnabled)
        .accessibilityLabel(Text(isRecording ? "Stop recording" : "Start recording"))
    }

    /// Outer rings swell more than inner ones, so loud speech spreads the halo apart.
    private func halo(swell: CGFloat) -> some View {
        ZStack {
            ForEach(Array(Self.haloScales.enumerated().reversed()), id: \.offset) { index, scale in
                let grown = scale + swell * Self.haloSwell * CGFloat(index + 1)
                Circle()
                    .fill(Color.interactive.opacity(isEnabled ? 0.16 - Double(index) * 0.04 : 0.05))
                    .frame(width: Self.buttonSize * grown, height: Self.buttonSize * grown)
            }
        }
    }

    /// Ripples always travel at the same pace; loudness sets how far and how visibly they spread, so silence shows none.
    private func ripples(at time: TimeInterval, loudness: Double) -> some View {
        ZStack {
            ForEach(0..<Self.rippleCount, id: \.self) { index in
                let phase = (time / Self.ripplePeriod + Double(index) / Double(Self.rippleCount))
                    .truncatingRemainder(dividingBy: 1)
                let fade = (1 - phase) * loudness
                Circle()
                    .strokeBorder(Color.interactive.opacity(0.5 * fade), lineWidth: 2)
                    .background(Circle().fill(Color.interactive.opacity(0.14 * fade)))
                    .frame(width: Self.buttonSize, height: Self.buttonSize)
                    .scaleEffect(1 + phase * (0.4 + 0.6 * loudness))
            }
        }
    }
}

/// Level bars under the button, driven by the microphone's loudness.
private struct ListeningBars: View {
    let level: () -> Double

    @Environment(\.motion) private var motion

    private static let peakHeights: [CGFloat] = [8, 16, 12, 18, 10]
    private static let minHeight: CGFloat = 4

    var body: some View {
        TimelineView(.animation(paused: motion.reduceMotion)) { context in
            let time = context.date.timeIntervalSinceReferenceDate
            let loudness = motion.reduceMotion ? 0.5 : level()
            HStack(spacing: 4) {
                ForEach(Self.peakHeights.indices, id: \.self) { index in
                    // A little per-bar wobble keeps the bars from moving as one block.
                    let wobble = motion.reduceMotion ? 1 : 0.75 + 0.25 * sin(time * 9 + Double(index) * 1.7)
                    Capsule()
                        .fill(Color.interactive)
                        .frame(width: 4, height: max(Self.minHeight, Self.peakHeights[index] * CGFloat(loudness * wobble)))
                }
            }
            .frame(height: 18)
        }
        .accessibilityHidden(true)
    }
}
