import Foundation

/// One file of the model, pinned by SHA-256 (ADR-003).
public struct ModelFile: Sendable, Equatable {
    public let name: String
    public let sha256: String
    public let bytes: Int64

    /// nil means the file is absent. Checked after each download.
    public func isValid(sha256 digest: String?) -> Bool { digest == sha256 }

    /// The launch check: hashing the encoder there costs 2.3-2.6 s on the reference Mac. nil means absent.
    public func isComplete(bytes size: Int64?) -> Bool { size == bytes }
}

/// Parakeet TDT 0.6B v3 int8; scripts/fetch-deps.sh pins the same files for the bench.
public enum ParakeetModel {
    public static let baseURL = "https://huggingface.co/csukuangfj/sherpa-onnx-nemo-parakeet-tdt-0.6b-v3-int8/resolve/ed5d745623472f97cfc2e6c2916ee248798fc5a8"
    public static let files = [
        ModelFile(name: "encoder.int8.onnx", sha256: "1afbe69c1ffdabee94755f42e4daf1d93549131a3da11356bda84fcef0f2c479", bytes: 652_282_294),
        ModelFile(name: "decoder.int8.onnx", sha256: "0222a86147299d4dee90edf95b6d13827edb42ad8b7c9cf0b2582f030937c0b5", bytes: 11_845_274),
        ModelFile(name: "joiner.int8.onnx", sha256: "cbd02f3696e9944970111fb439d9c3fd365a80374565f13f2b9c7007d253fc98", bytes: 6_355_277),
        ModelFile(name: "tokens.txt", sha256: "d58544679ea4bc6ac563d1f545eb7d474bd6cfa467f0a6e2c1dc1c7d37e3c35d", bytes: 93_939),
    ]
    public static var bytes: Int64 { files.reduce(0) { $0 + $1.bytes } }
}

/// Truncated, so the menu never shows 100% before the last byte.
public func downloadStatus(received: Int64, total: Int64) -> String {
    String(format: "Downloading model: %lld%% of %.0f MB", min(received, total) * 100 / max(total, 1), Double(total) / 1_000_000)
}
