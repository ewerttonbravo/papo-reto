namespace PapoReto.Core;

/// <summary>What the tray shows; the adapter maps each one to an icon.</summary>
public enum TrayIcon { Loading, Ready, Unavailable, Listening, Thinking }

public abstract record AppEvent
{
    public sealed record ModelLoaded : AppEvent;
    public sealed record ModelFailed : AppEvent;
    /// <summary>Null on the first press since launch.</summary>
    public sealed record HotkeyPressed(TimeSpan? SinceRelease) : AppEvent;
    public sealed record HotkeyReleased(TimeSpan HeldFor) : AppEvent;
    /// <summary>The process's private bytes right after the transcription, in MB.</summary>
    public sealed record Transcribed(double PrivateMB) : AppEvent;
    /// <summary>The microphone could not start (e.g. blocked in Windows privacy settings).</summary>
    public sealed record RecordingFailed : AppEvent;
    /// <summary>The adapter's timer: RecordingLimit after the start.</summary>
    public sealed record RecordingLimitReached : AppEvent;
}

/// <summary>What the adapters must do after a transition.</summary>
public enum AppEffect { StartRecording, StopRecording, DiscardRecording, Transcribe, ReloadModel }

/// <summary>Port of the Swift AppState, growing per task with only the transitions it uses.</summary>
public sealed record AppState
{
    public enum ModelState { Loading, Ready, Unavailable }
    public enum ActivityState { Idle, Recording, HandsFree, Transcribing }

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

    public ModelState Model { get; init; } = ModelState.Loading;
    public ActivityState Activity { get; init; } = ActivityState.Idle;
    /// <summary>The last release was a tap; the next press consumes it.</summary>
    public bool AfterTap { get; init; }

    public TrayIcon Icon => (Activity, Model) switch
    {
        (ActivityState.Recording or ActivityState.HandsFree, _) => TrayIcon.Listening,
        (ActivityState.Transcribing, _) => TrayIcon.Thinking,
        (_, ModelState.Loading) => TrayIcon.Loading,
        (_, ModelState.Ready) => TrayIcon.Ready,
        _ => TrayIcon.Unavailable,
    };

    public (AppState State, AppEffect[] Effects) Handling(AppEvent e) => (e, Model, Activity) switch
    {
        (AppEvent.ModelLoaded, ModelState.Loading, _) =>
            (this with { Model = ModelState.Ready }, Activity == ActivityState.Transcribing ? [AppEffect.Transcribe] : []),
        // Audio waiting for this model would wait forever: drop it.
        (AppEvent.ModelFailed, ModelState.Loading, _) =>
            (new AppState { Model = ModelState.Unavailable }, Activity == ActivityState.Idle ? [] : [AppEffect.DiscardRecording]),
        (AppEvent.HotkeyPressed p, ModelState.Loading or ModelState.Ready, ActivityState.Idle) =>
            (this with
            {
                Activity = AfterTap && p.SinceRelease < DoubleTapWindow ? ActivityState.HandsFree : ActivityState.Recording,
                AfterTap = false,
            }, [AppEffect.StartRecording]),
        (AppEvent.HotkeyPressed, _, ActivityState.HandsFree) => StoppingToTranscribe(),
        // In hands-free, a tap then a hold to talk: the hold's release ends it like push-to-talk.
        (AppEvent.HotkeyReleased r, _, ActivityState.Recording or ActivityState.HandsFree) when r.HeldFor > HoldThreshold =>
            StoppingToTranscribe(),
        (AppEvent.RecordingLimitReached, _, ActivityState.Recording or ActivityState.HandsFree) => StoppingToTranscribe(),
        (AppEvent.HotkeyReleased, _, ActivityState.Recording) =>
            (this with { Activity = ActivityState.Idle, AfterTap = true }, [AppEffect.DiscardRecording]),
        (AppEvent.RecordingFailed, _, ActivityState.Recording) => (this with { Activity = ActivityState.Idle }, []),
        (AppEvent.Transcribed t, _, ActivityState.Transcribing) when t.PrivateMB >= ReloadAtPrivateMB =>
            (new AppState { Model = ModelState.Loading }, [AppEffect.ReloadModel]),
        (AppEvent.Transcribed, _, ActivityState.Transcribing) => (this with { Activity = ActivityState.Idle }, []),
        _ => (this, []),
    };

    /// <summary>Without the model the audio waits; ModelLoaded transcribes it.</summary>
    (AppState, AppEffect[]) StoppingToTranscribe() =>
        (this with { Activity = ActivityState.Transcribing },
            Model == ModelState.Ready ? [AppEffect.StopRecording, AppEffect.Transcribe] : [AppEffect.StopRecording]);
}
