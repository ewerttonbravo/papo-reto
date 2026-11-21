using System.Diagnostics;
using PapoReto.Core;
using PapoReto.Sherpa;

// Reports like the Swift bench and checks the text against its output; no budget verdict on Windows (ADR-028).
if (args.Length < 3 || args[0] != "--reference")
{
    Console.WriteLine("usage: papo-reto-bench --reference <Mac bench output> <wav>...");
    return 2;
}
var mac = BenchTranscript.Parse(File.ReadAllText(args[1]));

var proc = Process.GetCurrentProcess();
var sw = Stopwatch.StartNew();
var transcriber = new Transcriber();
var load = sw.Elapsed.TotalSeconds;
proc.Refresh();
Console.WriteLine($"load {load:F2} s · private {proc.PrivateMemorySize64 / 1e6:F0} MB · working set {proc.WorkingSet64 / 1e6:F0} MB · threads {transcriber.Threads}");

var texts = new List<(string File, string Text)>();
foreach (var file in args.Skip(2))
{
    var (rate, samples) = ReadWav(file);
    var audio = samples.Length / (double)rate;
    sw.Restart();
    var text = transcriber.Transcribe(samples, rate);
    var latency = sw.Elapsed.TotalSeconds;
    texts.Add((Path.GetFileName(file), text));
    Console.WriteLine($"{Path.GetFileName(file)} · audio {audio:F1} s · {latency:F2} s · {latency * 10 / audio:F2} s per 10 s");
    Console.WriteLine($"  {text}");
}
proc.Refresh();
Console.WriteLine($"after transcribing: private {proc.PrivateMemorySize64 / 1e6:F0} MB · working set {proc.WorkingSet64 / 1e6:F0} MB · peak working set {proc.PeakWorkingSet64 / 1e6:F0} MB");

var divergences = BenchTranscript.Divergences(mac, texts);
if (divergences.Count == 0)
{
    Console.WriteLine("text matches the Mac");
    return 0;
}
foreach (var d in divergences) Console.WriteLine($"text differs: {d}");
return 3;

// 16-bit PCM mono only: the bench WAVs are made with ffmpeg -ac 1 -ar 16000 -c:a pcm_s16le, or by say.
static (int rate, float[] samples) ReadWav(string path)
{
    using var r = new BinaryReader(File.OpenRead(path));
    if (new string(r.ReadChars(4)) != "RIFF") throw new InvalidDataException(path);
    r.ReadInt32();
    if (new string(r.ReadChars(4)) != "WAVE") throw new InvalidDataException(path);
    int rate = 0;
    while (true)
    {
        var id = new string(r.ReadChars(4));
        var size = r.ReadInt32();
        if (id == "fmt ")
        {
            var format = r.ReadInt16();
            var channels = r.ReadInt16();
            rate = r.ReadInt32();
            r.ReadBytes(6);
            var bits = r.ReadInt16();
            if (format != 1 || channels != 1 || bits != 16) throw new InvalidDataException($"{path}: not 16-bit PCM mono");
            r.ReadBytes(size - 16);
        }
        else if (id == "data")
        {
            var bytes = r.ReadBytes(size);
            var samples = new float[bytes.Length / 2];
            for (int i = 0; i < samples.Length; i++) samples[i] = BitConverter.ToInt16(bytes, i * 2) / 32768f;
            return (rate, samples);
        }
        else r.ReadBytes(size);
    }
}
