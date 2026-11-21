namespace PapoReto.Core;

/// <summary>The system clipboard as the Core sees it; a snapshot holds every format the user had copied.</summary>
public interface IClipboard<TSnapshot>
{
    /// <summary>GetClipboardSequenceNumber: changes on every write by anyone.</summary>
    uint Sequence { get; }
    TSnapshot Snapshot();
    /// <summary>Writes text marked so that the history, the cloud clipboard and clipboard managers skip it.</summary>
    void WriteExcluded(string text);
}

public interface IKeyboard
{
    void PressCtrlV();
}

/// <summary>The clipboard the user had before a paste, to put back once the target app has read the text.</summary>
public sealed class PendingRestore<TSnapshot>(TSnapshot snapshot, uint sequence)
{
    public TSnapshot Snapshot { get; } = snapshot;
    public uint Sequence { get; } = sequence;
}

public static class Paster
{
    /// <summary>Pastes <paramref name="text"/> at the cursor through the clipboard, keeping what it held before.</summary>
    public static PendingRestore<TSnapshot> Paste<TSnapshot>(string text, IClipboard<TSnapshot> clipboard, IKeyboard keyboard)
    {
        var previous = clipboard.Snapshot();
        clipboard.WriteExcluded(text);
        var pending = new PendingRestore<TSnapshot>(previous, clipboard.Sequence);
        keyboard.PressCtrlV();
        return pending;
    }
}
