using System.Globalization;

namespace PapoReto.Core;

/// <summary>One file of the model, pinned by SHA-256 (ADR-003).</summary>
public sealed record ModelFile(string Name, string Sha256, long Bytes)
{
    /// <summary>Null means the file is absent. Checked after each download and on Retry.</summary>
    public bool IsValid(string? sha256) => sha256 == Sha256;

    /// <summary>The launch check, as on the Mac (ADR-018). Null means absent.</summary>
    public bool IsComplete(long? bytes) => bytes == Bytes;
}

/// <summary>Parakeet TDT 0.6B v3 int8; the Swift Core and scripts/fetch-deps.sh pin the same files.</summary>
public static class ParakeetModel
{
    public const string BaseUrl = "https://huggingface.co/csukuangfj/sherpa-onnx-nemo-parakeet-tdt-0.6b-v3-int8/resolve/ed5d745623472f97cfc2e6c2916ee248798fc5a8";

    public static readonly IReadOnlyList<ModelFile> Files =
    [
        new("encoder.int8.onnx", "1afbe69c1ffdabee94755f42e4daf1d93549131a3da11356bda84fcef0f2c479", 652_282_294),
        new("decoder.int8.onnx", "0222a86147299d4dee90edf95b6d13827edb42ad8b7c9cf0b2582f030937c0b5", 11_845_274),
        new("joiner.int8.onnx", "cbd02f3696e9944970111fb439d9c3fd365a80374565f13f2b9c7007d253fc98", 6_355_277),
        new("tokens.txt", "d58544679ea4bc6ac563d1f545eb7d474bd6cfa467f0a6e2c1dc1c7d37e3c35d", 93_939),
    ];

    public static long Bytes => Files.Sum(f => f.Bytes);

    /// <summary>Truncated, so the menu never shows 100% before the last byte.</summary>
    public static string DownloadStatus(long received, long total) => string.Create(CultureInfo.InvariantCulture,
        $"Downloading model: {Math.Min(received, total) * 100 / Math.Max(total, 1)}% of {total / 1e6:F0} MB");
}
