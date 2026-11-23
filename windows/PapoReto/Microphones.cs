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
        try
        {
            using var devices = new MMDeviceEnumerator();
            return devices.EnumerateAudioEndPoints(DataFlow.Capture, DeviceState.Active).Select(d =>
            {
                using (d) return new InputDevice(d.ID, d.FriendlyName);
            }).ToList();
        }
        catch (Exception e)
        {
            Log.Write("audio", $"Could not list the microphones: {e.Message}");
            return [];
        }
    }

    public static string? Load()
    {
        try { return File.ReadAllText(FilePath).Trim() is { Length: > 0 } id ? id : null; }
        catch (IOException) { return null; }
        catch (UnauthorizedAccessException) { return null; }
    }

    /// <summary>Null deletes the file: the app follows the Windows default.</summary>
    public static void Save(string? id)
    {
        try
        {
            if (id is null) File.Delete(FilePath);
            else File.WriteAllText(FilePath, id);
        }
        catch (Exception e) when (e is IOException or UnauthorizedAccessException)
        {
            Log.Write("audio", $"Could not save the microphone: {e.Message}");
        }
    }

    /// <summary>Device names often carry the owner's name: hashed, still telling devices apart.</summary>
    public static string Hash(string name) => Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(name)))[..8];
}
