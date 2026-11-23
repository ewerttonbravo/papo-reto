namespace PapoReto.Core;

public static class Microphone
{
    /// <summary>Endpoint ID to record from; null means the Windows default. A saved device that is gone
    /// stays saved, so it is used again as soon as it reconnects (ADR-015).</summary>
    public static string? InUse(string? saved, IReadOnlyCollection<string> connected) =>
        saved is not null && connected.Contains(saved) ? saved : null;
}
