using System.Diagnostics;
using PapoReto.Core;
using PapoReto.Sherpa;

namespace PapoReto;

static class Program
{
    [STAThread]
    static void Main()
    {
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
    // Until W07 downloads it, the model comes from the Mac's make win-bench.
    readonly ToolStripMenuItem modelMissing = new("Model not found. Run make win-bench on the Mac") { Enabled = false };
    AppState state = new();
    // Resident (ADR-003); W03 transcribes with it.
    Transcriber? transcriber;

    public TrayContext()
    {
        menu.Items.Add(modelMissing);
        menu.Items.Add("Quit", null, (_, _) => ExitThread());
        tray.ContextMenuStrip = menu;
        Render();
        _ = LoadModel();
    }

    async Task LoadModel()
    {
        var clock = Stopwatch.StartNew();
        try
        {
            transcriber = await Task.Run(() => new Transcriber());
            Log.Write("model", $"Loaded in {clock.Elapsed.TotalSeconds:F2} s, {transcriber.Threads} threads");
            Apply(AppEvent.ModelLoaded);
        }
        catch (Exception e)
        {
            Log.Write("model", $"Load failed after {clock.Elapsed.TotalSeconds:F2} s: {e.Message}");
            Apply(AppEvent.ModelFailed);
        }
    }

    void Apply(AppEvent e)
    {
        state = state.Handling(e);
        Render();
    }

    void Render()
    {
        tray.Icon = IconFor(state.Icon);
        modelMissing.Visible = state.Model == AppState.ModelState.Unavailable;
    }

    // Provisional until W12 draws the profile.
    static Icon IconFor(TrayIcon icon) => icon switch
    {
        TrayIcon.Loading => SystemIcons.Application,
        TrayIcon.Ready => SystemIcons.Information,
        TrayIcon.Unavailable => SystemIcons.Warning,
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
