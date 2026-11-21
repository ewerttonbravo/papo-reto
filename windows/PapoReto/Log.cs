namespace PapoReto;

/// <summary>%LOCALAPPDATA%\PapoReto\papo-reto.log, recreated at each launch. Never the transcribed text.</summary>
static class Log
{
    static readonly string FilePath = Path.Combine(
        Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "PapoReto", "papo-reto.log");

    public static void Start()
    {
        Write(() =>
        {
            Directory.CreateDirectory(Path.GetDirectoryName(FilePath)!);
            File.WriteAllText(FilePath, "");
        });
    }

    public static void Write(string category, string message) =>
        Write(() => File.AppendAllText(FilePath, $"{DateTime.Now:yyyy-MM-dd HH:mm:ss.fff} [{category}] {message}{Environment.NewLine}"));

    // A failing disk must not stop the app: the log is for diagnosis only.
    static void Write(Action io)
    {
        try { io(); } catch (IOException) { } catch (UnauthorizedAccessException) { }
    }
}
