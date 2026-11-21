namespace PapoReto.Core;

/// <summary>What the tray shows; the adapter maps each one to an icon.</summary>
public enum TrayIcon { Loading, Ready, Unavailable }

public enum AppEvent { ModelLoaded, ModelFailed }

/// <summary>Port of the Swift AppState, growing per task with only the transitions it uses.</summary>
public sealed record AppState
{
    public enum ModelState { Loading, Ready, Unavailable }

    public ModelState Model { get; init; } = ModelState.Loading;

    public TrayIcon Icon => Model switch
    {
        ModelState.Loading => TrayIcon.Loading,
        ModelState.Ready => TrayIcon.Ready,
        _ => TrayIcon.Unavailable,
    };

    public AppState Handling(AppEvent e) => Model != ModelState.Loading ? this : this with
    {
        Model = e == AppEvent.ModelLoaded ? ModelState.Ready : ModelState.Unavailable,
    };
}
