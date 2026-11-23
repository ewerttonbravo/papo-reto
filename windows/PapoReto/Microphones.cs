using System.Security.Cryptography;
using System.Text;
using NAudio.CoreAudioApi;

namespace PapoReto;

sealed record InputDevice(string Id, string Name);

/// <summary>Active capture endpoints, and the chosen one's ID in %LOCALAPPDATA%\PapoReto\microphone (ADR-015).</summary>
static class Microphones
{
    static readonly string FilePath = Path.Combine(
        Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "PapoReto", "microphone");

    /// <summary>Empty when Windows cannot list them: the menu still offers the default.</summary>
    public static List<InputDevice> Active()
    {
        var active = new List<InputDevice>();
        try
        {
            using var devices = new MMDeviceEnumerator();
            foreach (var d in devices.EnumerateAudioEndPoints(DataFlow.Capture, DeviceState.Active))
                using (d)
                {
                    // A driver whose properties fail to open costs only its own entry.
                    try { active.Add(new InputDevice(d.ID, d.FriendlyName)); }
                    catch (Exception e) { Log.Write("audio", $"Skipped a microphone: {e.Message}"); }
                }
        }
        catch (Exception e)
        {
            Log.Write("audio", $"Could not list the microphones: {e.Message}");
        }
        return active;
    }

    public static string? Load()
    {
        try { return File.ReadAllText(FilePath).Trim() is { Length: > 0 } id ? id : null; }
        catch (Exception e) when (e is FileNotFoundException or DirectoryNotFoundException) { return null; }
        catch (Exception e) when (e is IOException or UnauthorizedAccessException)
        {
            Log.Write("audio", $"Could not read the saved microphone, using the system default: {e.Message}");
            return null;
        }
    }

    /// <summary>Null deletes the file: the app follows the Windows default.</summary>
    public static void Save(string? id)
    {
        try
        {
            if (id is null) File.Delete(FilePath);
            else
            {
                // Deleting the folder is the cleanup: it may be gone while the app runs.
                Directory.CreateDirectory(Path.GetDirectoryName(FilePath)!);
                File.WriteAllText(FilePath, id);
            }
        }
        catch (Exception e) when (e is IOException or UnauthorizedAccessException)
        {
            Log.Write("audio", $"Could not save the microphone: {e.Message}");
        }
    }

    /// <summary>Device names often carry the owner's name: hashed, still telling devices apart.</summary>
    public static string Hash(string name) => Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(name)))[..8];
}
