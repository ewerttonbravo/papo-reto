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
            if (file.Length > 1) texts[file[0]] = lines[i + 1].TrimEnd('\r')[2..];
        }
        return texts;
    }
}
