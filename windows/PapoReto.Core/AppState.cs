namespace PapoReto.Core;

/// <summary>What the tray shows; the adapter maps each one to an icon.</summary>
public enum TrayIcon { Loading, Ready, Unavailable, Listening, Thinking }

public abstract record AppEvent
{
    public sealed record ModelLoaded : AppEvent;
    public sealed record ModelFailed : AppEvent;
    public sealed record HotkeyPressed : AppEvent;
    public sealed record HotkeyReleased(TimeSpan HeldFor) : AppEvent;
    public sealed record Transcribed : AppEvent;
}

/// <summary>What the adapters must do after a transition.</summary>
public enum AppEffect { StartRecording, StopRecording, DiscardRecording, Transcribe }

/// <summary>Port of the Swift AppState, growing per task with only the transitions it uses.</summary>
public sealed record AppState
{
    public enum ModelState { Loading, Ready, Unavailable }
    public enum ActivityState { Idle, Recording, Transcribing }

    /// <summary>Holding the hotkey longer than this is push-to-talk (ADR-005); shorter is a tap.</summary>
    public static readonly TimeSpan HoldThreshold = TimeSpan.FromMilliseconds(300);

    public ModelState Model { get; init; } = ModelState.Loading;
    public ActivityState Activity { get; init; } = ActivityState.Idle;

    public TrayIcon Icon => (Activity, Model) switch
    {
        (ActivityState.Recording, _) => TrayIcon.Listening,
        (ActivityState.Transcribing, _) => TrayIcon.Thinking,
        (_, ModelState.Loading) => TrayIcon.Loading,
        (_, ModelState.Ready) => TrayIcon.Ready,
        _ => TrayIcon.Unavailable,
    };

    public (AppState State, AppEffect[] Effects) Handling(AppEvent e) => (e, Model, Activity) switch
    {
        (AppEvent.ModelLoaded, ModelState.Loading, _) => (this with { Model = ModelState.Ready }, []),
        (AppEvent.ModelFailed, ModelState.Loading, _) => (this with { Model = ModelState.Unavailable }, []),
        (AppEvent.HotkeyPressed, ModelState.Ready, ActivityState.Idle) =>
            (this with { Activity = ActivityState.Recording }, [AppEffect.StartRecording]),
        (AppEvent.HotkeyReleased r, _, ActivityState.Recording) when r.HeldFor > HoldThreshold =>
            (this with { Activity = ActivityState.Transcribing }, [AppEffect.StopRecording, AppEffect.Transcribe]),
        (AppEvent.HotkeyReleased, _, ActivityState.Recording) =>
            (this with { Activity = ActivityState.Idle }, [AppEffect.DiscardRecording]),
        (AppEvent.Transcribed, _, ActivityState.Transcribing) => (this with { Activity = ActivityState.Idle }, []),
        _ => (this, []),
    };
}
