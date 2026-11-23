using System.Net;
using System.Security.Cryptography;
using PapoReto.Core;

namespace PapoReto;

/// <summary>Checks the model files and downloads the ones missing, verifying each by SHA-256:
/// the app's only network use (ADR-002).</summary>
static class ModelStore
{
    // No cache on disk; redirects to the CDN are followed.
    static readonly HttpClient Http = new();
    // HttpClient.Timeout ends at the headers: without this, a dropped network could hang the body forever.
    static readonly TimeSpan Stall = TimeSpan.FromSeconds(30);

    /// <summary>Absent or truncated files. By size, not hash, as on the Mac (ADR-018).</summary>
    public static List<ModelFile> MissingFiles(string dir) =>
        ParakeetModel.Files.Where(f => !f.IsComplete(Size(Path.Combine(dir, f.Name)))).ToList();

    /// <summary>Files whose SHA-256 fails, for Retry: a same-size corrupt file would fail again.</summary>
    public static List<ModelFile> InvalidFiles(string dir) =>
        ParakeetModel.Files.Where(f => !f.IsValid(Sha256(Path.Combine(dir, f.Name)))).ToList();

    /// <summary>Each file goes to `name.part`, hashed as it is written, and is renamed only if the hash matches;
    /// an interrupted file starts over.</summary>
    public static async Task Download(List<ModelFile> files, string dir, IProgress<string> progress)
    {
        Directory.CreateDirectory(dir);
        long total = files.Sum(f => f.Bytes), received = 0;
        var shown = ParakeetModel.DownloadStatus(0, total);
        progress.Report(shown);
        var buffer = new byte[1 << 20];
        foreach (var file in files)
        {
            var part = Path.Combine(dir, file.Name + ".part");
            try
            {
                using var response = await Http.GetAsync($"{ParakeetModel.BaseUrl}/{file.Name}", HttpCompletionOption.ResponseHeadersRead);
                if (response.StatusCode != HttpStatusCode.OK)
                    throw new HttpRequestException($"HTTP {(int)response.StatusCode} for {file.Name}");
                using var hash = IncrementalHash.CreateHash(HashAlgorithmName.SHA256);
                await using (var body = await response.Content.ReadAsStreamAsync())
                await using (var output = File.Create(part))
                {
                    int read;
                    while ((read = await ReadWithin(Stall, body, buffer)) > 0)
                    {
                        hash.AppendData(buffer, 0, read);
                        await output.WriteAsync(buffer.AsMemory(0, read));
                        received += read;
                        // Every 1 MB at most: only a new percent reaches the UI thread.
                        var status = ParakeetModel.DownloadStatus(received, total);
                        if (status != shown) progress.Report(shown = status);
                    }
                }
                if (!file.IsValid(Convert.ToHexStringLower(hash.GetHashAndReset())))
                    throw new InvalidDataException($"SHA-256 mismatch for {file.Name}");
                File.Move(part, Path.Combine(dir, file.Name), overwrite: true);
            }
            finally
            {
                File.Delete(part);
            }
        }
    }

    static async Task<int> ReadWithin(TimeSpan limit, Stream body, byte[] buffer)
    {
        using var stall = new CancellationTokenSource(limit);
        return await body.ReadAsync(buffer, stall.Token);
    }

    static long? Size(string path)
    {
        var info = new FileInfo(path);
        return info.Exists ? info.Length : null;
    }

    /// <summary>Null when the file is absent or unreadable.</summary>
    static string? Sha256(string path)
    {
        try
        {
            using var stream = File.OpenRead(path);
            return Convert.ToHexStringLower(SHA256.HashData(stream));
        }
        catch (IOException) { return null; }
        catch (UnauthorizedAccessException) { return null; }
    }
}
