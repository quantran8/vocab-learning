import AVFoundation
import Observation

@MainActor
protocol AudioClipPlaying: AnyObject {
    var isPlaying: Bool { get }
    var canPlay: Bool { get }
    /// Returns true only if sound really started, which is what `deliveryMode: audio` claims.
    func play(_ url: URL) async -> Bool
    func stop()
}

/// Plays prompt audio. Clips are downloaded first, so a failed load is known rather than assumed.
@Observable
@MainActor
final class AudioClipPlayer: NSObject, AudioClipPlaying {
    private(set) var isPlaying = false

    @ObservationIgnored private var player: AVAudioPlayer?
    @ObservationIgnored private var cache: [URL: Data] = [:]

    var canPlay: Bool { !AVAudioSession.sharedInstance().currentRoute.outputs.isEmpty }

    func play(_ url: URL) async -> Bool {
        stop()
        do {
            let data = try await clip(url)
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio)
            try AVAudioSession.sharedInstance().setActive(true)
            let player = try AVAudioPlayer(data: data)
            player.delegate = self
            self.player = player
            isPlaying = player.play()
            return isPlaying
        } catch {
            isPlaying = false
            return false
        }
    }

    func stop() {
        player?.stop()
        player = nil
        isPlaying = false
    }

    private func clip(_ url: URL) async throws -> Data {
        if let cached = cache[url] { return cached }
        let (data, response) = try await URLSession.shared.data(from: url)
        guard (response as? HTTPURLResponse).map({ (200..<300).contains($0.statusCode) }) ?? false else {
            throw URLError(.badServerResponse)
        }
        cache[url] = data
        return data
    }
}

extension AudioClipPlayer: AVAudioPlayerDelegate {
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in self.isPlaying = false }
    }
}

final class SilentAudioClips: AudioClipPlaying {
    let isPlaying = false
    let canPlay = false
    func play(_ url: URL) async -> Bool { false }
    func stop() {}
}

@MainActor
protocol VoiceRecording: AnyObject {
    /// False once the learner has denied the microphone.
    var canRecord: Bool { get }
    /// Fires when the time limit stops a recording.
    var onLimitReached: (@MainActor () -> Void)? { get set }
    func requestAccess() async -> Bool
    func start() throws
    /// Ends the recording and returns it; nil if nothing usable was captured.
    func stop() -> RecordedAudio?
    func cancel()
}

/// Records 16 kHz mono PCM WAV for Azure Speech. The time limit keeps uploads well under the 2 MB cap.
@MainActor
final class VoiceRecorder: NSObject, VoiceRecording {
    private static let maxDuration: TimeInterval = 20

    var onLimitReached: (@MainActor () -> Void)?

    private var recorder: AVAudioRecorder?
    private let fileURL = FileManager.default.temporaryDirectory.appending(path: "vocabflow-recording.wav")

    var canRecord: Bool { AVAudioApplication.shared.recordPermission != .denied }

    func requestAccess() async -> Bool {
        await AVAudioApplication.requestRecordPermission()
    }

    func start() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .measurement, options: [.defaultToSpeaker])
        try session.setActive(true)
        let recorder = try AVAudioRecorder(url: fileURL, settings: [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: 16_000,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: false,
        ])
        recorder.delegate = self
        guard recorder.record(forDuration: Self.maxDuration) else {
            throw CocoaError(.fileWriteUnknown)
        }
        self.recorder = recorder
    }

    func stop() -> RecordedAudio? {
        recorder?.stop()
        recorder = nil
        defer { try? FileManager.default.removeItem(at: fileURL) }
        guard let data = try? Data(contentsOf: fileURL), !data.isEmpty else { return nil }
        return RecordedAudio(data: data)
    }

    func cancel() {
        recorder?.stop()
        recorder = nil
        try? FileManager.default.removeItem(at: fileURL)
    }
}

extension VoiceRecorder: AVAudioRecorderDelegate {
    nonisolated func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        // A manual stop has already cleared `self.recorder`, so this only fires for the limit.
        Task { @MainActor in
            guard self.recorder != nil else { return }
            self.onLimitReached?()
        }
    }
}

final class NoVoiceRecorder: VoiceRecording {
    let canRecord = false
    var onLimitReached: (@MainActor () -> Void)?
    func requestAccess() async -> Bool { false }
    func start() throws { throw CocoaError(.featureUnsupported) }
    func stop() -> RecordedAudio? { nil }
    func cancel() {}
}
