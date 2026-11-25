namespace PapoReto.Core;

/// <summary>What the tray shows; the adapter maps each one to an icon.</summary>
public enum TrayIcon { Loading, Downloading, Ready, Unavailable, Listening, Thinking }

public abstract record AppEvent
{
    public sealed record ModelLoaded : AppEvent;
    public sealed record ModelFailed : AppEvent;
    /// <summary>A model file is absent or truncated: the adapter downloads it, verifies its SHA-256, then loads.</summary>
    public sealed record DownloadStarted : AppEvent;
    /// <summary>The menu's Retry after a failed download or load.</summary>
    public sealed record RetryRequested : AppEvent;
    /// <summary>Null on the first press since launch.</summary>
    public sealed record HotkeyPressed(TimeSpan? SinceRelease) : AppEvent;
    public sealed record HotkeyReleased(TimeSpan HeldFor) : AppEvent;
    /// <summary>Any key down but AltGr and the modifiers. While AltGr is held any key cancels;
    /// hands-free only Esc (ADR-017).</summary>
    public sealed record KeyPressed(bool IsEscape) : AppEvent;
    /// <summary>The process's private bytes right after the transcription, in MB.</summary>
    public sealed record Transcribed(double PrivateMB) : AppEvent;
    /// <summary>The microphone could not start (e.g. blocked in Windows privacy settings).</summary>
    public sealed record RecordingFailed : AppEvent;
    /// <summary>The adapter's timer: RecordingLimit after the start.</summary>
    public sealed record RecordingLimitReached : AppEvent;
}

/// <summary>What the adapters must do after a transition. PrepareModel: check every file's SHA-256
/// (Retry; the launch checks sizes), download what fails, then load.</summary>
public enum AppEffect { StartRecording, StopRecording, DiscardRecording, Transcribe, ReloadModel, PrepareModel }

/// <summary>Port of the Swift AppState, growing per task with only the transitions it uses.</summary>
public sealed record AppState
{
    public enum ModelState { Loading, Downloading, Ready, Unavailable }
    /// <summary>HandsFreeHeld: AltGr still down from the double tap's second press, so a key is a combination.</summary>
    public enum ActivityState { Idle, Recording, HandsFreeHeld, HandsFree, Transcribing }

    /// <summary>Holding the hotkey longer than this is push-to-talk (ADR-005); shorter is a tap.</summary>
    public static readonly TimeSpan HoldThreshold = TimeSpan.FromMilliseconds(300);
    /// <summary>A press this soon after a tap's release is a double tap: hands-free (ADR-005, ADR-017).</summary>
    public static readonly TimeSpan DoubleTapWindow = TimeSpan.FromMilliseconds(400);
    /// <summary>The recognizer keeps the RAM of the longest audio it saw; here it is recreated (ADR-038).
    /// What the bench leaves after clips of up to 28 s, the Mac's rule (ADR-016).</summary>
    public const double ReloadAtPrivateMB = 1_300;
    /// <summary>A recording stops by itself here and is transcribed whole, which bounds the RAM peak (ADR-016).
    /// It also ends one whose release the hook never saw (the lock screen).</summary>
    public static readonly TimeSpan RecordingLimit = TimeSpan.FromSeconds(120);
    /// <summary>Shorter audio is a slip, not dictation, and the model makes words up for it (0.35 s → "It was").</summary>
    public static readonly TimeSpan MinimumAudio = TimeSpan.FromMilliseconds(400);

    public static bool IsLongEnough(int sampleCount, int sampleRate) =>
        // In ticks, not a double: 6,400 samples are exactly the boundary.
        (long)sampleCount * TimeSpan.TicksPerSecond / sampleRate >= MinimumAudio.Ticks;

    public ModelState Model { get; init; } = ModelState.Loading;
    public ActivityState Activity { get; init; } = ActivityState.Idle;
    /// <summary>The last release was a tap; the next press consumes it.</summary>
    public bool AfterTap { get; init; }

    /// <summary>The microphone is on: push-to-talk or hands-free.</summary>
    bool Listening => Activity is ActivityState.Recording or ActivityState.HandsFreeHeld or ActivityState.HandsFree;

    public TrayIcon Icon => (Activity, Model) switch
    {
        _ when Listening => TrayIcon.Listening,
        (ActivityState.Transcribing, _) => TrayIcon.Thinking,
        (_, ModelState.Loading) => TrayIcon.Loading,
        (_, ModelState.Downloading) => TrayIcon.Downloading,
        (_, ModelState.Ready) => TrayIcon.Ready,
        _ => TrayIcon.Unavailable,
    };

    public (AppState State, AppEffect[] Effects) Handling(AppEvent e) => (e, Model, Activity) switch
    {
        (AppEvent.ModelLoaded, ModelState.Loading or ModelState.Downloading, _) =>
            (this with { Model = ModelState.Ready }, Activity == ActivityState.Transcribing ? [AppEffect.Transcribe] : []),
        (AppEvent.ModelFailed, ModelState.Loading or ModelState.Downloading, _) => DroppingAudio(ModelState.Unavailable),
        (AppEvent.DownloadStarted, ModelState.Loading, _) => DroppingAudio(ModelState.Downloading),
        (AppEvent.RetryRequested, ModelState.Unavailable, _) => (new AppState(), [AppEffect.PrepareModel]),
        (AppEvent.HotkeyPressed p, ModelState.Loading or ModelState.Ready, ActivityState.Idle) =>
            (this with
            {
                Activity = AfterTap && p.SinceRelease < DoubleTapWindow ? ActivityState.HandsFreeHeld : ActivityState.Recording,
                AfterTap = false,
            }, [AppEffect.StartRecording]),
        (AppEvent.HotkeyPressed, _, ActivityState.HandsFree) => StoppingToTranscribe(),
        // A tap then a hold to talk: the hold's release ends it like push-to-talk.
        (AppEvent.HotkeyReleased r, _, ActivityState.Recording or ActivityState.HandsFreeHeld) when r.HeldFor > HoldThreshold =>
            StoppingToTranscribe(),
        (AppEvent.RecordingLimitReached, _, _) when Listening => StoppingToTranscribe(),
        (AppEvent.HotkeyReleased, _, ActivityState.Recording) =>
            (this with { Activity = ActivityState.Idle, AfterTap = true }, [AppEffect.DiscardRecording]),
        (AppEvent.HotkeyReleased, _, ActivityState.HandsFreeHeld) => (this with { Activity = ActivityState.HandsFree }, []),
        (AppEvent.KeyPressed, _, ActivityState.Recording or ActivityState.HandsFreeHeld)
            or (AppEvent.KeyPressed { IsEscape: true }, _, ActivityState.HandsFree) =>
            (this with { Activity = ActivityState.Idle }, [AppEffect.DiscardRecording]),
        (AppEvent.RecordingFailed, _, _) when Listening => (this with { Activity = ActivityState.Idle }, []),
        (AppEvent.Transcribed t, _, ActivityState.Transcribing) when t.PrivateMB >= ReloadAtPrivateMB =>
            (new AppState { Model = ModelState.Loading }, [AppEffect.ReloadModel]),
        (AppEvent.Transcribed, _, ActivityState.Transcribing) => (this with { Activity = ActivityState.Idle }, []),
        _ => (this, []),
    };

    /// <summary>Audio waiting for this model would wait forever (or for minutes): drop it.</summary>
    (AppState, AppEffect[]) DroppingAudio(ModelState model) =>
        (new AppState { Model = model }, Activity == ActivityState.Idle ? [] : [AppEffect.DiscardRecording]);

    /// <summary>Without the model the audio waits; ModelLoaded transcribes it.</summary>
    (AppState, AppEffect[]) StoppingToTranscribe() =>
        (this with { Activity = ActivityState.Transcribing },
            Model == ModelState.Ready ? [AppEffect.StopRecording, AppEffect.Transcribe] : [AppEffect.StopRecording]);
}
