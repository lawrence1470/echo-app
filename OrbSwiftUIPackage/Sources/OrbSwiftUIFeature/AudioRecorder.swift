import AVFoundation
import Observation

@Observable
@MainActor
final class AudioRecorder {

    enum State: Equatable {
        case idle
        case recording
        case transcribing
    }

    private(set) var state: State = .idle
    private(set) var intensity: Float = 0       // 0-1 normalized mic level
    private(set) var duration: TimeInterval = 0 // seconds
    private(set) var recordedFileURL: URL?      // last recorded audio file

    var isRecording: Bool { state == .recording }
    var isTranscribing: Bool { state == .transcribing }
    var permissionGranted: Bool { AVAudioApplication.shared.recordPermission == .granted }

    // MARK: - Private

    private var recorder: AVAudioRecorder?
    private var meteringTimer: Timer?
    private var durationTimer: Timer?

    private let noiseFloor: Float = -45
    private let voiceThreshold: Float = -35

    // MARK: - Permission

    func requestPermission() async -> Bool {
        await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
    }

    // MARK: - Recording

    func startRecording() {
        guard state == .idle else { return }

        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playAndRecord, mode: .default)
            try session.setActive(true)
        } catch {
            print("Audio session error: \(error)")
            return
        }

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("m4a")

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue,
        ]

        do {
            let rec = try AVAudioRecorder(url: url, settings: settings)
            rec.isMeteringEnabled = true
            rec.record()
            recorder = rec
        } catch {
            print("Recorder init error: \(error)")
            return
        }

        duration = 0
        intensity = 0
        state = .recording

        // Metering at 50ms
        meteringTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.updateMetering() }
        }

        // Duration at 100ms
        durationTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.updateDuration() }
        }
    }

    func stopRecording() {
        guard state == .recording else { return }
        meteringTimer?.invalidate()
        durationTimer?.invalidate()
        meteringTimer = nil
        durationTimer = nil

        recordedFileURL = recorder?.url
        recorder?.stop()
        recorder = nil

        state = .transcribing
        intensity = 0
    }

    func finishTranscribing() {
        state = .idle
    }

    func cancelRecording() {
        guard state == .recording else { return }
        meteringTimer?.invalidate()
        durationTimer?.invalidate()
        meteringTimer = nil
        durationTimer = nil
        recorder?.stop()
        recorder?.deleteRecording()
        recorder = nil
        state = .idle
        intensity = 0
        duration = 0
    }

    // MARK: - Private helpers

    private func updateMetering() {
        guard let rec = recorder, state == .recording else { return }
        rec.updateMeters()
        let dB = rec.averagePower(forChannel: 0)
        // Normalize: noiseFloor → 0, voiceThreshold → ~0.5-1
        let clamped = max(noiseFloor, min(0, dB))
        let range = -noiseFloor // e.g. 45
        let normalized = (clamped - noiseFloor) / range
        // Apply curve so voice range (above threshold) maps to higher values
        let thresholdNorm = (voiceThreshold - noiseFloor) / range
        let scaled: Float
        if normalized < thresholdNorm {
            scaled = normalized * 0.3 / thresholdNorm
        } else {
            scaled = 0.3 + (normalized - thresholdNorm) / (1 - thresholdNorm) * 0.7
        }
        intensity = max(0, min(1, scaled))
    }

    private func updateDuration() {
        guard state == .recording else { return }
        duration += 0.1
    }
}
