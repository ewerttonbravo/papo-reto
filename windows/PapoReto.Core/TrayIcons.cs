namespace PapoReto.Core;

public static class TrayIcons
{
    /// <summary>The profile .ico next to the exe, in the ink that reads on the taskbar; null keeps the
    /// system icon, as the Mac keeps SF Symbols for its rare states (ADR-025).</summary>
    public static string? FileFor(TrayIcon icon, bool lightTaskbar)
    {
        var state = icon switch
        {
            TrayIcon.Ready => "ready",
            TrayIcon.Listening => "listening",
            TrayIcon.Thinking => "thinking",
            _ => null,
        };
        return state is null ? null : $"tray-{state}-{(lightTaskbar ? "black" : "white")}.ico";
    }

    /// <summary>A contrast theme repaints the taskbar in its background color without changing
    /// SystemUsesLightTheme; otherwise that value is 1 for a light taskbar, and absent before Windows 10 1903,
    /// whose taskbar is always dark.</summary>
    public static bool LightTaskbar(bool highContrast, bool contrastBackgroundIsLight, int? systemUsesLightTheme) =>
        highContrast ? contrastBackgroundIsLight : systemUsesLightTheme == 1;
}
