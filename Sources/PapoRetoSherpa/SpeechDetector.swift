import CSherpaOnnx
import Foundation

/// Silero VAD through the sherpa-onnx C API (ADR-019). Created per dictation and freed after it (ADR-020).
/// `@unchecked Sendable`: one transcription uses it at a time, then drops it.
public final class SpeechDetector: @unchecked Sendable {
    private static let window = 512
    private let detector: OpaquePointer

    public init?(model: URL) {
        // The C config only borrows these pointers, so they live until the detector exists.
        let strings = [model.path, "cpu"].map { (s: String) in strdup(s) }
        defer { strings.forEach { free($0) } }
        // Measured on the reference Mac (ADR-019): these settings tell every clip apart, speech from noise.
        var config = SherpaOnnxVadModelConfig()
        config.silero_vad.model = UnsafePointer(strings[0])
        config.silero_vad.threshold = 0.5
        config.silero_vad.min_silence_duration = 0.25
        config.silero_vad.min_speech_duration = 0.25
        config.silero_vad.window_size = Int32(Self.window)
        config.silero_vad.max_speech_duration = 150
        config.sample_rate = 16000
        config.num_threads = 1
        config.provider = UnsafePointer(strings[1])
        // The check stops at the first speech, so the buffer never holds more than its start.
        guard let detector = SherpaOnnxCreateVoiceActivityDetector(&config, 10) else { return nil }
        self.detector = detector
    }

    deinit { SherpaOnnxDestroyVoiceActivityDetector(detector) }

    /// 16 kHz mono Float32. Stops at the first speech: ≤ 10 ms on real speech, ~5 ms per second of silence.
    public func containsSpeech(_ samples: [Float]) -> Bool {
        samples.withUnsafeBufferPointer { buffer in
            var start = 0
            while start + Self.window <= buffer.count {
                SherpaOnnxVoiceActivityDetectorAcceptWaveform(detector, buffer.baseAddress! + start, Int32(Self.window))
                if foundSpeech { return true }
                start += Self.window
            }
            SherpaOnnxVoiceActivityDetectorFlush(detector)
            return foundSpeech
        }
    }

    private var foundSpeech: Bool {
        SherpaOnnxVoiceActivityDetectorDetected(detector) != 0 || SherpaOnnxVoiceActivityDetectorEmpty(detector) == 0
    }
}
