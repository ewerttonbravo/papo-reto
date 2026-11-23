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
    // The download's progress, or the Retry after a failure; hidden otherwise.
    readonly ToolStripMenuItem modelStatus = new();
    string downloadStatus = "";
    readonly ToolStripMenuItem microphoneMenu = new("Microphone");
    readonly AudioRecorder recorder = new();
    readonly WindowsClipboard clipboard = new();
    readonly WindowsKeyboard keyboard = new();
    readonly HotkeyMonitor? hotkey;
    // One shot per recording, on the UI thread; restarted at each start, so a stale one never cuts the next recording.
    readonly System.Windows.Forms.Timer recordingLimit = new() { Interval = (int)AppState.RecordingLimit.TotalMilliseconds };
    AppState state = new();
    // Resident (ADR-003).
    Transcriber? transcriber;
    // Stopped audio waiting for the model or the transcription.
    Task<float[]>? pendingAudio;
    // Endpoint ID; null follows the Windows default. Kept while the device is gone (ADR-015).
    string? savedMicrophone = Microphones.Load();

    public TrayContext()
    {
        modelStatus.Click += (_, _) => Apply(new AppEvent.RetryRequested());
        menu.Items.Add(modelStatus);
        // A child until the first opening, or the submenu shows no arrow.
        microphoneMenu.DropDownItems.Add("System Default");
        // Listed on each opening, so a device plugged in later shows up without polling.
        microphoneMenu.DropDownOpening += (_, _) => ListMicrophones();
        menu.Items.Add(microphoneMenu);
        menu.Items.Add("Quit", null, (_, _) => ExitThread());
        tray.ContextMenuStrip = menu;
        Render();
        recorder.Failed += () =>
        {
            recordingLimit.Stop();
            Apply(new AppEvent.RecordingFailed());
        };
        recordingLimit.Tick += (_, _) =>
        {
            recordingLimit.Stop();
            Log.Write("audio", "Recording limit reached");
            Apply(new AppEvent.RecordingLimitReached());
        };
        try
        {
            hotkey = new HotkeyMonitor(
                sinceRelease => Apply(new AppEvent.HotkeyPressed(sinceRelease)),
                held => Apply(new AppEvent.HotkeyReleased(held)),
                isEscape => Apply(new AppEvent.KeyPressed(isEscape)));
        }
        catch (Exception e)
        {
            Log.Write("hotkey", $"Keyboard hook failed: {e.Message}");
        }
        AudioRecorder.WarmUp();
        _ = PrepareModel(hashing: false);
    }

    /// <summary>Checks every file (by size; by SHA-256 on Retry), downloads the ones that fail, then loads.</summary>
    async Task PrepareModel(bool hashing)
    {
        var dir = Transcriber.DefaultModelDir;
        var clock = Stopwatch.StartNew();
        var invalid = await Task.Run(() => hashing ? ModelStore.InvalidFiles(dir) : ModelStore.MissingFiles(dir));
        Log.Write("model", $"Checked {(hashing ? "by SHA-256" : "by size")} in {clock.ElapsedMilliseconds} ms, {invalid.Count} files to download");
        if (invalid.Count > 0)
        {
            // Else a Retry would show the last failure's percent until the first report.
            downloadStatus = ParakeetModel.DownloadStatus(0, invalid.Sum(f => f.Bytes));
            Apply(new AppEvent.DownloadStarted());
            // Created here, on the UI thread, so each report is posted back to it in order.
            var progress = new Progress<string>(status =>
            {
                downloadStatus = status;
                Render();
            });
            clock.Restart();
            try
            {
                // Off the UI thread: the hash of each 1 MB runs where the read resumes.
                await Task.Run(() => ModelStore.Download(invalid, dir, progress));
            }
            catch (Exception e)
            {
                Log.Write("model", $"Download failed after {clock.Elapsed.TotalSeconds:F1} s: {e.GetType().Name}: {e.Message}");
                Apply(new AppEvent.ModelFailed());
                return;
            }
            Log.Write("model", $"Downloaded in {clock.Elapsed.TotalSeconds:F1} s");
        }
        await LoadModel();
    }

    async Task LoadModel()
    {
        // A corrupt file of the right size can abort in native code: this line without a "Loaded" one says so.
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
                try
                {
                    var clock = Stopwatch.StartNew();
                    var source = StartRecorder();
                    recordingLimit.Stop();
                    recordingLimit.Start();
                    Log.Write("audio", $"Recording from {source} started in {clock.ElapsedMilliseconds} ms");
                }
                catch (Exception e)
                {
                    Log.Write("audio", $"Recording failed to start: {e.Message}");
                    Apply(new AppEvent.RecordingFailed());
                }
                break;
            case AppEffect.StopRecording:
                recordingLimit.Stop();
                pendingAudio = recorder.Stop();
                break;
            case AppEffect.DiscardRecording:
                recordingLimit.Stop();
                Log.Write("audio", "Recording discarded");
                recorder.Stop();
                pendingAudio = null;
                break;
            case AppEffect.Transcribe:
                _ = Transcribe(pendingAudio!);
                break;
            case AppEffect.ReloadModel:
                // Destroyed first: both at once would peak at twice the RAM (ADR-016).
                transcriber!.Dispose();
                transcriber = null;
                _ = LoadModel();
                break;
            case AppEffect.PrepareModel:
                _ = PrepareModel(hashing: true);
                break;
        }
    }

    /// <summary>Returns what the log names: the chosen device's hash or the system default.</summary>
    string StartRecorder()
    {
        // Without a saved choice there is nothing to look up.
        if (savedMicrophone is not null && CurrentMicrophone(Microphones.Active()) is { } chosen)
        {
            var hash = Microphones.Hash(chosen.Name);
            try
            {
                recorder.Start(chosen.Id);
                return hash;
            }
            catch (Exception e)
            {
                // Gone between the listing and the start.
                Log.Write("audio", $"Could not record from {hash} ({e.Message}), trying the system default");
            }
        }
        recorder.Start(null);
        return "the system default";
    }

    /// <summary>The saved microphone while it is active; null records from the Windows default.</summary>
    InputDevice? CurrentMicrophone(List<InputDevice> active)
    {
        var id = Microphone.InUse(savedMicrophone, active.Select(d => d.Id).ToList());
        return active.Find(d => d.Id == id);
    }

    void ListMicrophones()
    {
        var active = Microphones.Active();
        var inUse = CurrentMicrophone(active)?.Id;
        var old = microphoneMenu.DropDownItems.Cast<ToolStripItem>().ToList();
        microphoneMenu.DropDownItems.Clear();
        old.ForEach(item => item.Dispose());
        microphoneMenu.DropDownItems.Add(MicrophoneChoice("System Default", null, inUse));
        foreach (var device in active) microphoneMenu.DropDownItems.Add(MicrophoneChoice(device.Name, device.Id, inUse));
    }

    ToolStripMenuItem MicrophoneChoice(string title, string? id, string? inUse) =>
        new(title, null, (_, _) => Microphones.Save(savedMicrophone = id)) { Checked = id == inUse };

    // The Core serializes transcriptions: one at a time on the resident recognizer.
    async Task Transcribe(Task<float[]> audio)
    {
        try
        {
            // From the stop, so the device's last buffer counts in what the user waits.
            var clock = Stopwatch.StartNew();
            var samples = await audio;
            var text = await Task.Run(() => transcriber!.Transcribe(samples, AudioRecorder.SampleRate));
            Log.Write("dictation", $"{(double)samples.Length / AudioRecorder.SampleRate:F2} s of audio transcribed in {clock.Elapsed.TotalSeconds:F2} s, private {PrivateMB():F0} MB");
            // Back on the UI thread, which owns the clipboard's window.
            if (FinalText.Of(text) is { } final) _ = RestoreLater(Paster.Paste(final, clipboard, keyboard), clipboard);
        }
        catch (Exception e)
        {
            // The message of a sherpa, clipboard or SendInput error, never the text.
            Log.Write("dictation", $"Failed: {e.Message}");
        }
        pendingAudio = null;
        var memory = PrivateMB();
        if (memory >= AppState.ReloadAtPrivateMB) Log.Write("model", $"Reloading the model at {memory:F0} MB private");
        Apply(new AppEvent.Transcribed(memory));
    }

    // Private bytes, as the bench reports: the working set is trimmed by Windows under pressure.
    static double PrivateMB()
    {
        using var process = Process.GetCurrentProcess();
        return process.PrivateMemorySize64 / 1e6;
    }

    static async Task RestoreLater<T>(PendingRestore<T> pending, IClipboard<T> clipboard)
    {
        // Time for the focused app to read the text before the user's clipboard comes back.
        await Task.Delay(250);
        try
        {
            pending.RestoreOn(clipboard);
        }
        catch (Exception e)
        {
            Log.Write("paste", $"Restore failed: {e.Message}");
        }
    }

    void Render()
    {
        tray.Icon = IconFor(state.Icon);
        var unavailable = state.Model == AppState.ModelState.Unavailable;
        modelStatus.Visible = unavailable || state.Model == AppState.ModelState.Downloading;
        modelStatus.Enabled = unavailable;
        modelStatus.Text = unavailable ? "Model unavailable. Retry" : downloadStatus;
    }

    // Provisional until W12 draws the profile.
    static Icon IconFor(TrayIcon icon) => icon switch
    {
        TrayIcon.Loading => SystemIcons.Application,
        TrayIcon.Downloading => SystemIcons.Shield,
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
        recordingLimit.Dispose();
        clipboard.Dispose();
        tray.Visible = false;
        tray.Dispose();
        menu.Dispose();
        base.ExitThreadCore();
    }
}
