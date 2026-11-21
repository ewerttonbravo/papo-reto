using PapoReto.Core;

namespace PapoReto;

static class Program
{
    [STAThread]
    static void Main()
    {
        ApplicationConfiguration.Initialize();
        Application.Run(new TrayContext());
    }
}

/// <summary>Tray only: no window and no taskbar button.</summary>
sealed class TrayContext : ApplicationContext
{
    readonly NotifyIcon tray = new() { Text = "Papo Reto", Visible = true };
    // NotifyIcon.Dispose leaves its menu alive.
    readonly ContextMenuStrip menu = new();

    public TrayContext()
    {
        tray.Icon = IconFor(new AppState().Icon);
        menu.Items.Add("Quit", null, (_, _) => ExitThread());
        tray.ContextMenuStrip = menu;
    }

    // Provisional until W12 draws the profile.
    static Icon IconFor(TrayIcon icon) => icon switch
    {
        TrayIcon.Loading => SystemIcons.Application,
        _ => throw new ArgumentOutOfRangeException(nameof(icon)),
    };

    protected override void ExitThreadCore()
    {
        // Hidden first, or the icon lingers in the tray until the mouse passes over it.
        tray.Visible = false;
        tray.Dispose();
        menu.Dispose();
        base.ExitThreadCore();
    }
}
