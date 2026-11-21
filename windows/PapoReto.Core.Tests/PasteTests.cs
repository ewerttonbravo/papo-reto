namespace PapoReto.Core.Tests;

/// <summary>In-memory clipboard whose snapshot is its list of items; keyboard calls land in the same log.</summary>
sealed class FakeClipboard(params string[] items) : IClipboard<string[]>, IKeyboard
{
    public string[] Items = items;
    public uint Sequence { get; set; }
    public readonly List<string> Calls = [];

    public string[] Snapshot() { Calls.Add("snapshot"); return Items; }
    public void WriteExcluded(string text) { Calls.Add($"write {text}"); Items = [text]; Sequence++; }
    public void Restore(string[] snapshot) { Calls.Add("restore"); Items = snapshot; Sequence++; }
    public void PressCtrlV() => Calls.Add("ctrl+v");
}

public class PasteTests
{
    [Fact]
    public void PasteWritesTheTextExcludedBeforeCtrlV()
    {
        var clipboard = new FakeClipboard("copied before");
        Paster.Paste("Bom dia.", clipboard, clipboard);
        Assert.Equal(["snapshot", "write Bom dia.", "ctrl+v"], clipboard.Calls);
    }

    [Fact]
    public void RestoreBringsBackThePreviousClipboard()
    {
        var clipboard = new FakeClipboard("copied before", "image");
        var pending = Paster.Paste("Bom dia.", clipboard, clipboard);
        pending.RestoreOn(clipboard);
        Assert.Equal(["copied before", "image"], clipboard.Items);
    }

    [Fact]
    public void RestoreKeepsAClipboardChangedAfterThePaste()
    {
        var clipboard = new FakeClipboard("copied before");
        var pending = Paster.Paste("Bom dia.", clipboard, clipboard);
        clipboard.Items = ["copied by the user"];
        clipboard.Sequence++;
        pending.RestoreOn(clipboard);
        Assert.Equal(["copied by the user"], clipboard.Items);
    }
}
