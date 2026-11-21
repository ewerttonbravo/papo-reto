using System.Runtime.InteropServices;
using SherpaOnnx;

namespace PapoReto.Sherpa;

/// <summary>Parakeet TDT v3 through the sherpa-onnx NuGet. Load once, then one stream per transcription.</summary>
public sealed class Transcriber
{
    public static readonly string DefaultModelDir = Path.Combine(
        Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
        "PapoReto", "Models", "parakeet-tdt-0.6b-v3-int8");

    readonly OfflineRecognizer recognizer;

    public int Threads { get; } = PhysicalCores();

    public Transcriber(string? modelDir = null)
    {
        var dir = modelDir ?? DefaultModelDir;
        // The NuGet does not check the native handle: a missing file would crash later, in native code.
        foreach (var f in new[] { "encoder.int8.onnx", "decoder.int8.onnx", "joiner.int8.onnx", "tokens.txt" })
            if (!File.Exists(Path.Combine(dir, f))) throw new FileNotFoundException($"No {f} in {dir}");
        var config = new OfflineRecognizerConfig();
        config.FeatConfig.SampleRate = 16000;
        config.FeatConfig.FeatureDim = 80;
        config.ModelConfig.Transducer.Encoder = Path.Combine(dir, "encoder.int8.onnx");
        config.ModelConfig.Transducer.Decoder = Path.Combine(dir, "decoder.int8.onnx");
        config.ModelConfig.Transducer.Joiner = Path.Combine(dir, "joiner.int8.onnx");
        config.ModelConfig.Tokens = Path.Combine(dir, "tokens.txt");
        config.ModelConfig.ModelType = "nemo_transducer";
        config.ModelConfig.Provider = "cpu";
        config.ModelConfig.NumThreads = Threads;
        config.DecodingMethod = "greedy_search";
        recognizer = new OfflineRecognizer(config);
    }

    /// <summary>Samples are mono, in [-1, 1].</summary>
    public string Transcribe(float[] samples, int sampleRate)
    {
        if (samples.Length == 0) return "";
        using var stream = recognizer.CreateStream();
        stream.AcceptWaveform(sampleRate, samples);
        recognizer.Decode(stream);
        return stream.Result.Text;
    }

    // As on the Mac (hw.physicalcpu): in the spike, 8 threads on the 4-core i5-8250U were no faster than 4.
    static int PhysicalCores()
    {
        if (!OperatingSystem.IsWindows()) return Environment.ProcessorCount;
        uint length = 0;
        GetLogicalProcessorInformationEx(RelationProcessorCore, IntPtr.Zero, ref length);
        var buffer = Marshal.AllocHGlobal((int)length);
        try
        {
            if (!GetLogicalProcessorInformationEx(RelationProcessorCore, buffer, ref length)) return Environment.ProcessorCount;
            // One variable-size record per core; its Size field sits after the 4-byte Relationship.
            int cores = 0;
            for (uint offset = 0; offset < length; offset += (uint)Marshal.ReadInt32(buffer, (int)offset + 4)) cores++;
            return Math.Max(cores, 1);
        }
        finally { Marshal.FreeHGlobal(buffer); }
    }

    const int RelationProcessorCore = 0;

    [DllImport("kernel32.dll", SetLastError = true)]
    static extern bool GetLogicalProcessorInformationEx(int relationship, IntPtr buffer, ref uint length);
}
