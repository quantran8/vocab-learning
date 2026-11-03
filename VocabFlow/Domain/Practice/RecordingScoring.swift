import Foundation

/// Who scores a recording task. See memory recording-scoring-modes.
enum RecordingScoring: Equatable {
    /// Upload the audio to `recording-assess`; the receipt is committed.
    case backend
    /// Transcribe on the device and compare with the task's `acceptedResponses`; each take commits as `transcribed`.
    case onDevice
}

/// Instant feedback only: the backend re-checks the committed transcript the same way.
/// A transcript can't measure pronunciation, so a take is only right or wrong and carries no score.
enum TranscriptMatcher {
    static func assess(_ candidates: [String], target: String) -> RecordingAssessment {
        let expected = normalize(target)
        // Only the recognizer's top pick counts: lower alternatives would let a wrong reading through.
        guard !expected.isEmpty, let heard = candidates.map(normalize).first(where: { !$0.isEmpty }) else {
            return RecordingAssessment(assessmentReceiptId: "on-device", validity: "invalid", passed: nil, accuracyScore: nil)
        }
        return RecordingAssessment(
            assessmentReceiptId: "on-device",
            validity: "valid",
            passed: heard == expected,
            accuracyScore: nil,
            heard: heard
        )
    }

    static func normalize(_ text: String) -> String {
        let folded = text.folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: Locale(identifier: "en_US"))
            .replacingOccurrences(of: "’", with: "'")
        let kept = folded.unicodeScalars.map { CharacterSet.alphanumerics.contains($0) || $0 == "'" ? Character($0) : " " }
        return String(kept).split(separator: " ").joined(separator: " ")
    }
}
