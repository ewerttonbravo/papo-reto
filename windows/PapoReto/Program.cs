using System.Diagnostics;
using PapoReto.Core;
using PapoReto.Sherpa;

namespace PapoReto;

static class Program
{
    [STAThread]
    static void Main()
    {
        // A second instance would overwrite the log and load another model.
        using var instance = new Mutex(true, @"Local\PapoReto", out var first);
        if (!first) return;
        ApplicationConfiguration.Initialize();
        // The model load resumes here, on the UI thread, once Application.Run pumps messages.
        SynchronizationContext.SetSynchronizationContext(new WindowsFormsSynchronizationContext());
        Log.Start();
        Application.Run(new TrayContext());
    }
}

/// <summary>Tray only: no window and no taskbar button.</summary>
sealed class TrayContext : ApplicationContext
{
    readonly NotifyIcon tray = new() { Text = "Papo Reto", Visible = true };
    // NotifyIcon.Dispose leaves its menu alive.
    readonly ContextMenuStrip menu = new();
    // Until W07 downloads it, the model comes from the Mac's make win-bench.
    readonly ToolStripMenuItem modelMissing = new("Model not found. Run make win-bench on the Mac") { Enabled = false };
    readonly AudioRecorder recorder = new();
    readonly HotkeyMonitor? hotkey;
    AppState state = new();
    // Resident (ADR-003).
    Transcriber? transcriber;
    // Stopped audio waiting for the model or the transcription.
    Task<float[]>? pendingAudio;

    public TrayContext()
    {
        menu.Items.Add(modelMissing);
        menu.Items.Add("Quit", null, (_, _) => ExitThread());
        tray.ContextMenuStrip = menu;
        Render();
        try
        {
            hotkey = new HotkeyMonitor(() => Apply(new AppEvent.HotkeyPressed()), held => Apply(new AppEvent.HotkeyReleased(held)));
        }
        catch (Exception e)
        {
            Log.Write("hotkey", $"Keyboard hook failed: {e.Message}");
        }
        _ = LoadModel();
    }

    async Task LoadModel()
    {
        // A corrupt file can abort in native code: this line without a "Loaded" one says so (W07 hashes before loading).
        Log.Write("model", "Loading");
        var clock = Stopwatch.StartNew();
        try
        {
            transcriber = await Task.Run(() => new Transcriber());
        }
        catch (Exception e)
        {
            Log.Write("model", $"Load failed after {clock.Elapsed.TotalSeconds:F2} s: {e.Message}");
            Apply(new AppEvent.ModelFailed());
            return;
        }
        Log.Write("model", $"Loaded in {clock.Elapsed.TotalSeconds:F2} s, {transcriber.Threads} threads");
        Apply(new AppEvent.ModelLoaded());
    }

    void Apply(AppEvent e)
    {
        (state, var effects) = state.Handling(e);
        Render();
        foreach (var effect in effects) Run(effect);
    }

    void Run(AppEffect effect)
    {
        switch (effect)
        {
            case AppEffect.StartRecording:
                try { recorder.Start(); }
                catch (Exception e)
                {
                    Log.Write("audio", $"Recording failed to start: {e.Message}");
                    Apply(new AppEvent.RecordingFailed());
                }
                break;
            case AppEffect.StopRecording:
                pendingAudio = recorder.Stop();
                break;
            case AppEffect.DiscardRecording:
                recorder.Stop();
                pendingAudio = null;
                break;
            case AppEffect.Transcribe:
                _ = Transcribe(pendingAudio!);
                break;
        }
    }

    // The Core serializes transcriptions: one at a time on the resident recognizer.
    async Task Transcribe(Task<float[]> audio)
    {
        try
        {
            var samples = await audio;
            var clock = Stopwatch.StartNew();
            var text = await Task.Run(() => transcriber!.Transcribe(samples, AudioRecorder.SampleRate));
            Log.Write("dictation", $"{(double)samples.Length / AudioRecorder.SampleRate:F2} s of audio transcribed in {clock.Elapsed.TotalSeconds:F2} s");
            // Back on the UI thread, which is STA as the clipboard requires.
            if (FinalText.Of(text) is { } final) Clipboard.SetText(final);
        }
        catch (Exception e)
        {
            // The message of a sherpa or clipboard error, never the text.
            Log.Write("dictation", $"Failed: {e.Message}");
        }
        pendingAudio = null;
        Apply(new AppEvent.Transcribed());
    }

    void Render()
    {
        tray.Icon = IconFor(state.Icon);
        modelMissing.Visible = state.Model == AppState.ModelState.Unavailable;
    }

    // Provisional until W12 draws the profile.
    static Icon IconFor(TrayIcon icon) => icon switch
    {
        TrayIcon.Loading => SystemIcons.Application,
        TrayIcon.Ready => SystemIcons.Information,
        TrayIcon.Unavailable => SystemIcons.Warning,
        TrayIcon.Listening => SystemIcons.Error,
        TrayIcon.Thinking => SystemIcons.Question,
        _ => throw new ArgumentOutOfRangeException(nameof(icon)),
    };

    protected override void ExitThreadCore()
    {
        // Hidden first, or the icon lingers in the tray until the mouse passes over it.
        hotkey?.Dispose();
        tray.Visible = false;
        tray.Dispose();
        menu.Dispose();
        base.ExitThreadCore();
    }
}
