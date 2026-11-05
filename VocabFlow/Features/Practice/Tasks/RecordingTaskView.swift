import SwiftUI

/// Read aloud, get scored, optionally read again. The last assessment is what gets committed.
struct RecordingTaskView: View {
    let attempt: TaskAttempt
    @Environment(PracticeSessionStore.self) private var store

    var body: some View {
        TaskScaffold(attempt: attempt, feedback: feedback) {
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
        // A take's result waits for "Try again" before the mic works again.
        case .uploading, .blocked, .assessed: false
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
        case .assessed:
            EmptyView()
        case .uploadFailed:
            statusText("Couldn’t check your recording.")
        case .blocked(let reason):
            statusText(reason == PracticeSessionStore.UnavailableReason.micDenied
                ? "Microphone access is off. You can turn it on in Settings."
                : "Recording isn’t available right now.")
        }
    }

    /// While a take's result is shown, the panel holds it and the mic waits for "Try again".
    private var feedback: FeedbackCopy? {
        guard case .assessed(let assessment) = store.recording else { return nil }
        guard assessment.isValid else {
            let title = attempt.canRecordAgain
                ? String(localized: "We couldn’t hear you clearly. Try reading again.", bundle: .appLanguage)
                : String(localized: "We couldn’t hear you clearly.", bundle: .appLanguage)
            return FeedbackCopy(kind: .info, title: title, message: "")
        }
        let passed = assessment.passed == true
        return FeedbackCopy(kind: passed ? .success : .error, title: resultTitle(passed: passed), message: resultMessage(assessment, passed: passed))
    }

    private func resultTitle(passed: Bool) -> String {
        if attempt.hasTranscripts {
            return passed ? String(localized: "Correct!", bundle: .appLanguage) : String(localized: "Not quite", bundle: .appLanguage)
        }
        if passed { return String(localized: "Great pronunciation!", bundle: .appLanguage) }
        return attempt.canRecordAgain ? String(localized: "Close. Try once more?", bundle: .appLanguage) : String(localized: "Close. Keep practicing.", bundle: .appLanguage)
    }

    private func resultMessage(_ assessment: RecordingAssessment, passed: Bool) -> String {
        if let score = assessment.accuracyScore {
            return score.formatted(.number.precision(.fractionLength(0)))
        }
        if let heard = assessment.heard, !passed {
            return String(localized: "We heard “\(heard)”", bundle: .appLanguage)
        }
        return ""
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
        case .assessed(let assessment) where assessment.passed == true || !attempt.canRecordAgain:
            PrimaryButton(title: "Continue") { store.acceptRecording() }
        case .assessed(let assessment):
            PrimaryButton(title: "Try again") { store.retryRecording() }
            // An invalid take is nothing to keep, so leaving it reads as skipping.
            SecondaryButton(title: assessment.isValid ? "Continue" : "Can’t speak now") { store.acceptRecording() }
        case .uploadFailed:
            PrimaryButton(title: "Try again") {
                Task { await store.retryUpload() }
            }
            SecondaryButton(title: "Skip") { store.acceptRecording() }
        case .blocked:
            PrimaryButton(title: "Continue") { store.acceptRecording() }
        case .idle:
            SecondaryButton(title: "Can’t speak now") { store.acceptRecording() }
        case .recording, .uploading:
            EmptyView()
        }
    }
}

/// Record control: breathes at rest; the halo and voice ripples appear only while the mic hears a voice.
private struct RecordingPulseButton: View {
    let isRecording: Bool
    let isEnabled: Bool
    let level: () -> Double
    let action: () -> Void

    @Environment(\.motion) private var motion

    private static let buttonSize: CGFloat = 128
    private static let haloScales: [CGFloat] = [1.3, 1.65, 2.0]
    /// Inner to outer ring, fading toward the canvas.
    private static let haloColors: [Color] = [.selectedDepth, .slotTargetedSurface, .selectedSurface]
    private static let haloSwell: CGFloat = 0.12
    private static let haloPulseDepth: CGFloat = 0.04
    private static let haloPulsePeriod: Double = 1.4
    private static let rippleCount = 3
    private static let ripplePeriod: Double = 2.1
    private static let breathDepth: CGFloat = 0.07
    private static let breathPeriod: Double = 3.2

    @State private var envelope = VoiceEnvelope()

    private var isLive: Bool { isRecording && !motion.reduceMotion }
    private var isBreathing: Bool { !isRecording && isEnabled && !motion.reduceMotion }

    var body: some View {
        TimelineView(.animation(paused: !isLive && !isBreathing)) { context in
            let time = context.date.timeIntervalSinceReferenceDate
            // Reduce Motion has no live level, so the halo stays on as the static recording cue.
            let voice = isLive
                ? envelope.update(level: level(), at: time)
                : VoiceEnvelope.Output(presence: isRecording ? 1 : 0, swell: 0)
            ZStack {
                ZStack {
                    halo(growth: CGFloat(voice.presence), swell: CGFloat(voice.swell), pulse: isLive ? pulse(at: time) : 0)
                        .compositingGroup()
                        .opacity(min(voice.presence * 2, 1))
                    if isLive {
                        ripples(at: time, presence: voice.presence, swell: voice.swell)
                    }
                }
                .allowsHitTesting(false)
                .accessibilityHidden(true)

                recordButton
                    .scaleEffect(isBreathing ? breath(at: time) : 1)
            }
            .animation(motion.animation(MotionTokens.transition), value: isRecording)
        }
        .frame(width: Self.buttonSize * 2.5, height: Self.buttonSize * 2.5)
    }

    /// A slow, steady swell of the halo while a voice is heard, independent of loudness.
    private func pulse(at time: TimeInterval) -> CGFloat {
        CGFloat(sin(time * 2 * .pi / Self.haloPulsePeriod))
    }

    private func breath(at time: TimeInterval) -> CGFloat {
        1 + Self.breathDepth * CGFloat(1 - cos(time * 2 * .pi / Self.breathPeriod)) / 2
    }

    private var recordButton: some View {
        Button(action: action) {
            Image(systemName: isRecording ? "pause.fill" : "play.fill")
                .font(.system(size: 46, weight: .bold))
                .foregroundStyle(isEnabled ? Color.surface : Color.disabledInk)
                .contentTransition(.symbolEffect(.replace))
                .frame(width: Self.buttonSize, height: Self.buttonSize)
                .background(isEnabled ? Color.interactive : Color.disabledSurface, in: Circle())
                .contentShape(Circle())
        }
        .buttonStyle(PressScaleButtonStyle())
        .disabled(!isEnabled)
        .accessibilityLabel(Text(isRecording ? "Stop recording" : "Start recording"))
    }

    /// Rings grow out from behind the button as `growth` goes 0 → 1.
    /// Outer rings swell and pulse more than inner ones, so the halo spreads apart while speaking.
    private func halo(growth: CGFloat, swell: CGFloat, pulse: CGFloat) -> some View {
        ZStack {
            ForEach(Array(Self.haloScales.enumerated().reversed()), id: \.offset) { index, scale in
                let reach = CGFloat(index + 1)
                let rest = 1 + (scale - 1) * growth
                let grown = rest + (swell * Self.haloSwell + pulse * Self.haloPulseDepth * growth) * reach
                Circle()
                    .fill(isEnabled ? Self.haloColors[index] : Color.disabledSurface)
                    .frame(width: Self.buttonSize * grown, height: Self.buttonSize * grown)
            }
        }
    }

    /// Ripples leave the button at a steady pace and ease out as they spread, like sound waves.
    /// Their visibility follows the smoothed presence, not the raw level, so they never flicker.
    private func ripples(at time: TimeInterval, presence: Double, swell: Double) -> some View {
        ZStack {
            ForEach(0..<Self.rippleCount, id: \.self) { index in
                let phase = (time / Self.ripplePeriod + Double(index) / Double(Self.rippleCount))
                    .truncatingRemainder(dividingBy: 1)
                let spread = 1 - (1 - phase) * (1 - phase)
                let fade = (1 - phase) * (1 - phase) * presence
                Circle()
                    .strokeBorder(Color.interactive.opacity(fade), lineWidth: 2)
                    .frame(width: Self.buttonSize, height: Self.buttonSize)
                    .scaleEffect(1 + spread * (0.95 + 0.25 * swell))
            }
        }
    }
}

/// Turns the jumpy mic level into a calm signal: the halo fades in when a voice starts,
/// holds through the short gaps between words, and fades out only after a real pause.
private final class VoiceEnvelope {
    struct Output {
        let presence: Double
        let swell: Double
    }

    /// Mic level where room noise ends and a voice begins.
    private static let voiceGate = 0.22
    /// Mic level span above the gate that maps to a full swell.
    private static let swellRange = 0.3
    /// How long the halo stays after the voice drops, bridging gaps between words.
    private static let hold: TimeInterval = 0.5
    /// Seconds for the halo to grow fully in, and to shrink back out.
    private static let growIn: TimeInterval = 0.55
    private static let shrinkOut: TimeInterval = 0.7
    private static let swellEase: TimeInterval = 0.2

    private var presence = 0.0
    private var swell = 0.0
    private var lastHeard = -Double.infinity
    private var lastTime: TimeInterval?

    func update(level: Double, at time: TimeInterval) -> Output {
        // A gap in updates means a new recording: start from silence, not from the last one's tail.
        if let lastTime, time - lastTime > 0.25 {
            presence = 0
            swell = 0
            lastHeard = -.infinity
        }
        let elapsed = lastTime.map { min(max(time - $0, 0), 0.1) } ?? 0
        lastTime = time

        if level > Self.voiceGate { lastHeard = time }
        let target = time - lastHeard < Self.hold ? 1.0 : 0
        // A steady ramp (not an exponential, which front-loads the change into the first frames),
        // eased at both ends on output, so the halo visibly grows instead of popping in.
        let step = elapsed / (target > presence ? Self.growIn : Self.shrinkOut)
        presence = target > presence ? min(presence + step, target) : max(presence - step, target)
        let eased = presence * presence * (3 - 2 * presence)

        let loud = min(max((level - Self.voiceGate) / Self.swellRange, 0), 1)
        swell = Self.approach(swell, loud, elapsed, Self.swellEase)

        return Output(presence: eased, swell: swell * eased)
    }

    private static func approach(_ value: Double, _ target: Double, _ elapsed: TimeInterval, _ timeConstant: TimeInterval) -> Double {
        value + (target - value) * (1 - exp(-elapsed / timeConstant))
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
