using System.Security.Cryptography;
using SherpaOnnx;

namespace PapoReto.Sherpa;

/// <summary>Silero VAD through the sherpa-onnx NuGet (ADR-019). Created per dictation and disposed after it (ADR-020).</summary>
public sealed class SpeechDetector : IDisposable
{
    const int Window = 512;
    // The pin in scripts/fetch-deps.sh.
    const string Sha256 = "9e2449e1087496d8d4caba907f23e0bd3f78d91fa552479bb9c23ac09cbb1fd6";
    readonly VoiceActivityDetector detector;

    public SpeechDetector(string model)
    {
        // The NuGet does not check the native handle: a missing, truncated or corrupt file gives a null detector
        // that reports no speech, dropping every dictation. Failing here makes the app transcribe anyway (ADR-020).
        if (!File.Exists(model)) throw new FileNotFoundException($"No {Path.GetFileName(model)}");
        if (Convert.ToHexStringLower(SHA256.HashData(File.ReadAllBytes(model))) != Sha256)
            throw new InvalidDataException($"SHA-256 mismatch for {Path.GetFileName(model)}");
        // The Mac's settings (ADR-019): they tell every measured clip apart, and a short "sim" still counts.
        var config = new VadModelConfig();
        config.SileroVad.Model = model;
        config.SileroVad.Threshold = 0.5f;
        config.SileroVad.MinSilenceDuration = 0.25f;
        config.SileroVad.MinSpeechDuration = 0.1f;
        config.SileroVad.WindowSize = Window;
        config.SileroVad.MaxSpeechDuration = 150;
        config.SampleRate = 16000;
        config.NumThreads = 1;
        config.Provider = "cpu";
        // The check stops at the first speech, so the buffer never holds more than its start.
        detector = new VoiceActivityDetector(config, 10);
    }

    /// <summary>16 kHz mono. Stops at the first speech.</summary>
    public bool ContainsSpeech(float[] samples)
    {
        var start = 0;
        for (; start + Window <= samples.Length; start += Window)
        {
            detector.AcceptWaveform(samples[start..(start + Window)]);
            if (FoundSpeech) return true;
        }
        // The last partial window, zero-padded: speech right before the release still counts.
        if (start < samples.Length)
        {
            var tail = new float[Window];
            Array.Copy(samples, start, tail, 0, samples.Length - start);
            detector.AcceptWaveform(tail);
        }
        detector.Flush();
        return FoundSpeech;
    }

    bool FoundSpeech => detector.IsSpeechDetected() || !detector.IsEmpty();

    public void Dispose() => detector.Dispose();
}
