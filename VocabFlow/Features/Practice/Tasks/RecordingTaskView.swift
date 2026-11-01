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
        Button {
            Task {
                if isRecording {
                    await store.stopRecording()
                } else {
                    await store.startRecording()
                }
            }
        } label: {
            Image(systemName: isRecording ? "stop.fill" : "mic.fill")
                .font(.system(size: 34, weight: .bold))
                .foregroundStyle(isRecording ? Color.errorInk : Color.selectedInk)
                .frame(width: 88, height: 88)
                .background(isRecording ? Color.errorSurface : Color.selectedSurface, in: Circle())
                .contentShape(Circle())
        }
        .buttonStyle(PressScaleButtonStyle())
        .disabled(!canUseMic)
        .accessibilityLabel(Text(isRecording ? "Stop recording" : "Start recording"))
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
            statusText("Listening… tap to stop.")
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
