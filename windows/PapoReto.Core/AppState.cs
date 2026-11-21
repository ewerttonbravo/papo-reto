namespace PapoReto.Core;

/// <summary>What the tray shows; the adapter maps each one to an icon.</summary>
public enum TrayIcon { Loading }

/// <summary>Port of the Swift AppState, growing per task with only the transitions it uses.</summary>
public sealed record AppState
{
    public enum ModelState { Loading }

    public ModelState Model { get; init; } = ModelState.Loading;

    public TrayIcon Icon => TrayIcon.Loading;
}
