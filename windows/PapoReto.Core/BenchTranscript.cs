namespace PapoReto.Core;

/// <summary>The text per WAV in a bench output, so the Windows bench can check it against the Mac's (ADR-028).</summary>
public static class BenchTranscript
{
    /// <summary>Each "name.wav · audio ..." line is followed by "  text".</summary>
    public static IReadOnlyDictionary<string, string> Parse(string output)
    {
        var lines = output.Split('\n');
        var texts = new Dictionary<string, string>();
        for (int i = 0; i + 1 < lines.Length; i++)
        {
            var file = lines[i].Split(" · audio ");
            if (file.Length > 1) texts[file[0]] = lines[i + 1][2..];
        }
        return texts;
    }

    /// <summary>One line per file whose text is not the Mac's; empty means the text matches.</summary>
    public static IReadOnlyList<string> Divergences(IReadOnlyDictionary<string, string> mac, IEnumerable<(string File, string Text)> windows) =>
        windows
            .Select(w => (w, Mac: mac.GetValueOrDefault(w.File)))
            .Where(x => x.Mac != x.w.Text)
            .Select(x => $"{x.w.File}: {(x.Mac is null ? "not in the Mac output" : $"Mac \"{x.Mac}\"")} · Windows \"{x.w.Text}\"")
            .ToList();
}
