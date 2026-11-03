import Foundation

/// Who scores a recording task. See memory recording-scoring-modes.
enum RecordingScoring: Equatable {
    /// Upload the audio to `recording-assess`; the receipt is committed.
    case backend
    /// Transcribe on the device and compare with the task's `acceptedResponses`; each take commits as `transcribed`.
    case onDevice
}

/// Instant feedback only: the backend re-scores the committed transcript the same way.
enum TranscriptMatcher {
    /// Same pass mark as the backend's `accuracyScore`.
    static let passScore = 80.0

    static func assess(_ candidates: [String], target: String) -> RecordingAssessment {
        let expected = normalize(target)
        let heard = candidates.map(normalize).filter { !$0.isEmpty }
        guard !expected.isEmpty, let best = heard.max(by: { similarity($0, expected) < similarity($1, expected) }) else {
            return RecordingAssessment(assessmentReceiptId: "on-device", validity: "invalid", passed: nil, accuracyScore: nil)
        }
        let score = (similarity(best, expected) * 100).rounded()
        return RecordingAssessment(
            assessmentReceiptId: "on-device",
            validity: "valid",
            passed: score >= passScore,
            accuracyScore: score,
            heard: best
        )
    }

    static func normalize(_ text: String) -> String {
        let folded = text.folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: Locale(identifier: "en_US"))
            .replacingOccurrences(of: "’", with: "'")
        let kept = folded.unicodeScalars.map { CharacterSet.alphanumerics.contains($0) || $0 == "'" ? Character($0) : " " }
        return String(kept).split(separator: " ").joined(separator: " ")
    }

    /// 1 minus the edit distance over the longer length.
    static func similarity(_ lhs: String, _ rhs: String) -> Double {
        let a = Array(lhs), b = Array(rhs)
        let longest = max(a.count, b.count)
        guard !a.isEmpty, !b.isEmpty else { return longest == 0 ? 1 : 0 }
        var previous = Array(0...b.count)
        for i in 1...a.count {
            var current = [i] + Array(repeating: 0, count: b.count)
            for j in 1...b.count {
                current[j] = min(previous[j] + 1, current[j - 1] + 1, previous[j - 1] + (a[i - 1] == b[j - 1] ? 0 : 1))
            }
            previous = current
        }
        return 1 - Double(previous[b.count]) / Double(longest)
    }
}
