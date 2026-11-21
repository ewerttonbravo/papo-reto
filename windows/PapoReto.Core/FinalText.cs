namespace PapoReto.Core;

public static class FinalText
{
    /// <summary>The text that goes to the user; null means there is nothing to deliver.</summary>
    public static string? Of(string transcription)
    {
        var text = transcription.Trim();
        return text.Length == 0 ? null : text;
    }
}
