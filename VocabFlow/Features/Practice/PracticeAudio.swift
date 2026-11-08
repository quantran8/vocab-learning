import AVFoundation
import Observation
import Speech

/// Activation blocks until the audio hardware answers, so it stays off the main thread.
/// The async system API needs iOS 27. As an actor, requests also can't overlap and clobber each other's category.
private actor AudioSessionActivator {
    static let shared = AudioSessionActivator()

    func activate(
        _ category: AVAudioSession.Category,
        mode: AVAudioSession.Mode,
        options: AVAudioSession.CategoryOptions = []
    ) throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(category, mode: mode, options: options)
        try session.setActive(true)
    }

    private struct Configuration {
        let category: AVAudioSession.Category
        let mode: AVAudioSession.Mode
        let options: AVAudioSession.CategoryOptions
    }

    /// The session from before the current recording; nil while not recording.
    private var beforeRecording: Configuration?
    private var recordingID = 0

    /// Switches to recording and returns the ID that `endRecording` needs to restore the session.
    func beginRecording() throws -> Int {
        let session = AVAudioSession.sharedInstance()
        if beforeRecording == nil {
            beforeRecording = Configuration(category: session.category, mode: session.mode, options: session.categoryOptions)
        }
        recordingID += 1
        do {
            try activate(.playAndRecord, mode: .measurement, options: [.defaultToSpeaker])
        } catch {
            endRecording(recordingID)
            throw error
        }
        return recordingID
    }

    /// `measurement` turns off output processing and `playAndRecord` plays at a lower volume,
    /// so leaving them on after a take makes every later sound quieter.
    /// Skipped when a newer recording has already started.
    func endRecording(_ id: Int) {
        guard id == recordingID, let saved = beforeRecording else { return }
        beforeRecording = nil
        try? AVAudioSession.sharedInstance().setCategory(saved.category, mode: saved.mode, options: saved.options)
    }
}

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
    /// Bumped by `stop()`, so a play still waiting on its clip or the session can tell it was called off.
    @ObservationIgnored private var playRequest = 0

    var canPlay: Bool { !AVAudioSession.sharedInstance().currentRoute.outputs.isEmpty }

    func play(_ url: URL) async -> Bool {
        stop()
        let request = playRequest
        do {
            let data = try await clip(url)
            // Checked before activating too: a stale play must not switch the category under a recording.
            guard request == playRequest else { return false }
            try await AudioSessionActivator.shared.activate(.playback, mode: .spokenAudio)
            guard request == playRequest else { return false }
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
        playRequest += 1
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
protocol SoundEffectsPlaying: AnyObject {
    func playCorrect()
    func playWrong()
    func playClick()
}

/// Short UI cues bundled in `Resources/Sounds`. Loaded once so they play without delay.
@MainActor
final class SoundEffects: SoundEffectsPlaying {
    private let player = CuePlayer()

    /// Preparing a player acquires audio hardware, which shouldn't hold up launch. A cue due before that finishes is skipped.
    init() {
        Task { [player] in await player.load() }
    }

    func playCorrect() { Task { [player] in await player.playAnswer(.correct) } }
    func playWrong() { Task { [player] in await player.playAnswer(.wrong) } }
    func playClick() { Task { [player] in await player.playClick() } }
}

/// Owns the cue players off the main thread: `play()` activates the audio session when it isn't active,
/// which blocks until the audio hardware answers.
private actor CuePlayer {
    enum Answer { case correct, wrong }

    private var correct: AVAudioPlayer?
    private var wrong: AVAudioPlayer?
    private var click: AVAudioPlayer?

    func load() {
        correct = Self.load("vocab_correct")
        wrong = Self.load("vocab_wrong")
        click = Self.load("click2")
    }

    func playClick() {
        click?.currentTime = 0
        click?.play()
    }

    /// An answer cue replaces the previous one instead of overlapping it.
    func playAnswer(_ answer: Answer) {
        guard let player = answer == .correct ? correct : wrong else { return }
        correct?.stop()
        wrong?.stop()
        player.currentTime = 0
        player.play()
    }

    private static func load(_ name: String) -> AVAudioPlayer? {
        guard let url = Bundle.main.url(forResource: name, withExtension: "wav"),
              let player = try? AVAudioPlayer(contentsOf: url)
        else { return nil }
        player.prepareToPlay()
        return player
    }
}

final class SilentSoundEffects: SoundEffectsPlaying {
    /// Nonisolated so it can be a default argument; conforming to the protocol makes the class main-actor.
    nonisolated init() {}

    func playCorrect() {}
    func playWrong() {}
    func playClick() {}
}

@MainActor
protocol VoiceRecording: AnyObject {
    /// False once the learner has denied the microphone.
    var canRecord: Bool { get }
    /// Fires when the time limit stops a recording.
    var onLimitReached: (@MainActor () -> Void)? { get set }
    /// Smoothed input loudness, 0 (silence) to 1. Polled every frame while recording.
    func inputLevel() -> Double
    func requestAccess() async -> Bool
    func start() async throws
    /// Ends the recording and returns it; nil if nothing usable was captured.
    func stop() -> RecordedAudio?
    func cancel()
}

/// Records 16 kHz mono PCM WAV for Azure Speech. The time limit keeps uploads well under the 2 MB cap.
@MainActor
final class VoiceRecorder: NSObject, VoiceRecording {
    private static let maxDuration: TimeInterval = 20

    var onLimitReached: (@MainActor () -> Void)?

    private static let silenceFloor: Float = -50
    /// Time constant of the level's fall between syllables.
    private static let levelRelease: TimeInterval = 0.25

    private var recorder: AVAudioRecorder?
    /// Set while the audio session is switched to recording.
    private var recordingSessionID: Int?
    private var smoothedLevel = 0.0
    private var lastLevelTime: TimeInterval = 0
    private let fileURL = FileManager.default.temporaryDirectory.appending(path: "vocabflow-recording.wav")

    var canRecord: Bool { AVAudioApplication.shared.recordPermission != .denied }

    func requestAccess() async -> Bool {
        await AVAudioApplication.requestRecordPermission()
    }

    func inputLevel() -> Double {
        guard let recorder, recorder.isRecording else { return 0 }
        let now = ProcessInfo.processInfo.systemUptime
        let elapsed = now - lastLevelTime
        // Several views read the level each frame; only the first read of a frame advances it.
        guard elapsed > 1.0 / 240 else { return smoothedLevel }
        lastLevelTime = now
        recorder.updateMeters()
        let power = max(recorder.averagePower(forChannel: 0), Self.silenceFloor)
        let level = Double((power - Self.silenceFloor) / -Self.silenceFloor)
        // Rise at once, fall over a fixed time (not per call), so the rings don't flicker between syllables.
        let keep = exp(-min(elapsed, 0.25) / Self.levelRelease)
        smoothedLevel = level > smoothedLevel ? level : smoothedLevel * keep + level * (1 - keep)
        return smoothedLevel
    }

    func start() async throws {
        let sessionID = try await AudioSessionActivator.shared.beginRecording()
        recordingSessionID = sessionID
        do {
            let recorder = try AVAudioRecorder(url: fileURL, settings: [
                AVFormatIDKey: kAudioFormatLinearPCM,
                AVSampleRateKey: 16_000,
                AVNumberOfChannelsKey: 1,
                AVLinearPCMBitDepthKey: 16,
                AVLinearPCMIsFloatKey: false,
                AVLinearPCMIsBigEndianKey: false,
            ])
            recorder.delegate = self
            recorder.isMeteringEnabled = true
            smoothedLevel = 0
            guard recorder.record(forDuration: Self.maxDuration) else {
                throw CocoaError(.fileWriteUnknown)
            }
            self.recorder = recorder
        } catch {
            restoreSession()
            throw error
        }
    }

    func stop() -> RecordedAudio? {
        recorder?.stop()
        recorder = nil
        restoreSession()
        defer { try? FileManager.default.removeItem(at: fileURL) }
        guard let data = try? Data(contentsOf: fileURL), !data.isEmpty else { return nil }
        return RecordedAudio(data: data)
    }

    func cancel() {
        recorder?.stop()
        recorder = nil
        restoreSession()
        try? FileManager.default.removeItem(at: fileURL)
    }

    private func restoreSession() {
        guard let id = recordingSessionID else { return }
        recordingSessionID = nil
        Task { await AudioSessionActivator.shared.endRecording(id) }
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
    func inputLevel() -> Double { 0 }
    func requestAccess() async -> Bool { false }
    func start() throws { throw CocoaError(.featureUnsupported) }
    func stop() -> RecordedAudio? { nil }
    func cancel() {}
}

@MainActor
protocol SpeechTranscribing: AnyObject {
    /// False when recognition can't run on this device: no permission, or no on-device model for English.
    func requestAccess() async -> Bool
    /// Candidate transcripts, best first; empty when nothing was recognized.
    func transcribe(_ audio: RecordedAudio) async -> [String]
}

/// Recognizes a finished take with Apple's on-device model, so no audio leaves the phone.
@MainActor
final class OnDeviceSpeechTranscriber: SpeechTranscribing {
    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private let fileURL = FileManager.default.temporaryDirectory.appending(path: "vocabflow-transcribe.wav")

    func requestAccess() async -> Bool {
        guard let recognizer, recognizer.supportsOnDeviceRecognition, recognizer.isAvailable else { return false }
        let status = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { continuation.resume(returning: $0) }
        }
        return status == .authorized
    }

    func transcribe(_ audio: RecordedAudio) async -> [String] {
        guard let recognizer, (try? audio.data.write(to: fileURL)) != nil else { return [] }
        defer { try? FileManager.default.removeItem(at: fileURL) }
        let request = SFSpeechURLRecognitionRequest(url: fileURL)
        request.requiresOnDeviceRecognition = true
        request.shouldReportPartialResults = false
        return await withCheckedContinuation { continuation in
            var resumed = false
            // Silence arrives as an error ("no speech detected"), which is an invalid take, not a failure.
            recognizer.recognitionTask(with: request) { result, error in
                guard !resumed else { return }
                if let result, result.isFinal {
                    resumed = true
                    continuation.resume(returning: result.transcriptions.map(\.formattedString))
                } else if error != nil {
                    resumed = true
                    continuation.resume(returning: [])
                }
            }
        }
    }
}

final class NoSpeechTranscriber: SpeechTranscribing {
    func requestAccess() async -> Bool { false }
    func transcribe(_ audio: RecordedAudio) async -> [String] { [] }
}
