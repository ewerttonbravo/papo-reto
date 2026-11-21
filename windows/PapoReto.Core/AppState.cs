namespace PapoReto.Core;

/// <summary>What the tray shows; the adapter maps each one to an icon.</summary>
public enum TrayIcon { Loading, Ready }

public enum AppEvent { ModelLoaded }

/// <summary>Port of the Swift AppState, growing per task with only the transitions it uses.</summary>
public sealed record AppState
{
    public enum ModelState { Loading, Ready }

    public ModelState Model { get; init; } = ModelState.Loading;

    public TrayIcon Icon => Model switch
    {
        ModelState.Loading => TrayIcon.Loading,
        _ => TrayIcon.Ready,
    };

    public AppState Handling(AppEvent e) => this with { Model = ModelState.Ready };
}
