import AVFoundation
import Observation

@MainActor
protocol SpeechProviding: AnyObject {
    var isAvailable: Bool { get }
    var isSpeaking: Bool { get }
    /// Returns false when playback could not start; callers must offer a non-audio path.
    func speak(_ text: String) -> Bool
    func stop()
}

/// Demo-only pronunciation via `AVSpeechSynthesizer`. Production audio would use curated clips.
@Observable
@MainActor
final class SpeechPlayer: NSObject, SpeechProviding {
    private(set) var isSpeaking = false
    let isAvailable: Bool

    @ObservationIgnored private let synthesizer = AVSpeechSynthesizer()
    @ObservationIgnored private let voice: AVSpeechSynthesisVoice?

    override init() {
        voice = AVSpeechSynthesisVoice(language: "en-US")
        isAvailable = voice != nil
        super.init()
        synthesizer.delegate = self
    }

    func speak(_ text: String) -> Bool {
        guard let voice else { return false }
        synthesizer.stopSpeaking(at: .immediate)
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = voice
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.85
        synthesizer.speak(utterance)
        isSpeaking = true
        return true
    }

    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
        isSpeaking = false
    }
}

extension SpeechPlayer: AVSpeechSynthesizerDelegate {
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in self.isSpeaking = false }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor in self.isSpeaking = false }
    }
}

final class SilentSpeech: SpeechProviding {
    let isAvailable = false
    let isSpeaking = false
    func speak(_ text: String) -> Bool { false }
    func stop() {}
}
