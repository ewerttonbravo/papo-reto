using NAudio.CoreAudioApi;
using NAudio.Wave;

namespace PapoReto;

/// <summary>The default microphone, on only while recording. Windows converts to 16 kHz mono float (AutoConvertPcm); samples stay in memory.</summary>
sealed class AudioRecorder
{
    public const int SampleRate = 16000;

    WasapiCapture? capture;
    Task<float[]> stopped = Task.FromResult(Array.Empty<float>());

    /// <summary>Throws when there is no microphone or Windows privacy settings block it.</summary>
    public void Start()
    {
        // One per recording, so a recording that is still stopping never mixes into the next one.
        var samples = new List<float>();
        var done = new TaskCompletionSource<float[]>();
        var c = new WasapiCapture { WaveFormat = WaveFormat.CreateIeeeFloatWaveFormat(SampleRate, 1) };
        c.DataAvailable += (_, e) =>
        {
            lock (samples)
                for (var i = 0; i + 4 <= e.BytesRecorded; i += 4) samples.Add(BitConverter.ToSingle(e.Buffer, i));
        };
        // Subscribed now: a device that disappears mid-recording stops it before Stop is called.
        // Raised on the UI thread (NAudio posts to the creating thread's context), where Dispose cannot join itself.
        c.RecordingStopped += (_, e) =>
        {
            c.Dispose();
            if (e.Exception is not null) Log.Write("audio", $"Recording stopped by an error: {e.Exception.Message}");
            lock (samples) done.SetResult(samples.ToArray());
        };
        try { c.StartRecording(); }
        catch { c.Dispose(); throw; }
        (capture, stopped) = (c, done.Task);
    }

    /// <summary>Completes with the samples once the device has delivered its last buffer.</summary>
    public Task<float[]> Stop()
    {
        capture?.StopRecording();
        capture = null;
        return stopped;
    }
}
