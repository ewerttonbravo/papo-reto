import CSherpaOnnx
import Foundation

/// Parakeet TDT v3 through the sherpa-onnx C API. Load once, then one stream per transcription.
public final class Transcriber {
    public static let defaultModelDir = FileManager.default
        .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("PapoReto/Models/parakeet-tdt-0.6b-v3-int8")

    private let recognizer: OpaquePointer

    public init?(modelDir: URL = defaultModelDir) {
        // The C config only borrows these pointers, so they live until the recognizer exists.
        let files = ["encoder.int8.onnx", "decoder.int8.onnx", "joiner.int8.onnx", "tokens.txt"]
            .map { modelDir.appendingPathComponent($0).path }
        let strings = (files + ["nemo_transducer", "greedy_search", "cpu"]).map { strdup($0) }
        defer { strings.forEach { free($0) } }

        var config = SherpaOnnxOfflineRecognizerConfig()
        config.feat_config.sample_rate = 16000
        config.feat_config.feature_dim = 80
        config.model_config.transducer.encoder = UnsafePointer(strings[0])
        config.model_config.transducer.decoder = UnsafePointer(strings[1])
        config.model_config.transducer.joiner = UnsafePointer(strings[2])
        config.model_config.tokens = UnsafePointer(strings[3])
        config.model_config.model_type = UnsafePointer(strings[4])
        config.decoding_method = UnsafePointer(strings[5])
        config.model_config.provider = UnsafePointer(strings[6])
        var cores: Int32 = 0
        var size = MemoryLayout<Int32>.size
        sysctlbyname("hw.physicalcpu", &cores, &size, nil, 0)
        config.model_config.num_threads = max(cores, 1)

        guard let recognizer = SherpaOnnxCreateOfflineRecognizer(&config) else { return nil }
        self.recognizer = recognizer
    }

    deinit { SherpaOnnxDestroyOfflineRecognizer(recognizer) }

    /// Samples are mono Float32 in [-1, 1].
    public func transcribe(samples: [Float], sampleRate: Int32) -> String {
        let stream = SherpaOnnxCreateOfflineStream(recognizer)
        defer { SherpaOnnxDestroyOfflineStream(stream) }
        SherpaOnnxAcceptWaveformOffline(stream, sampleRate, samples, Int32(samples.count))
        SherpaOnnxDecodeOfflineStream(recognizer, stream)
        guard let result = SherpaOnnxGetOfflineStreamResult(stream) else { return "" }
        defer { SherpaOnnxDestroyOfflineRecognizerResult(result) }
        return String(cString: result.pointee.text)
    }
}
