namespace PapoReto.Core.Tests;

public class ModelFilesTests
{
    static readonly ModelFile Encoder = ParakeetModel.Files[0];
    static readonly ModelFile Decoder = ParakeetModel.Files[1];

    [Fact]
    public void FileWithTheManifestHashIsValid()
    {
        foreach (var file in ParakeetModel.Files) Assert.True(file.IsValid(file.Sha256));
    }

    [Fact]
    public void AbsentOrDifferentHashIsInvalid()
    {
        Assert.False(Encoder.IsValid(null));
        Assert.False(Encoder.IsValid(Decoder.Sha256));
    }

    [Fact]
    public void FileOfTheManifestSizeIsComplete() => Assert.True(Encoder.IsComplete(Encoder.Bytes));

    /// <summary>The launch check: a truncated file (what makes sherpa abort) or one grown by an append fails it.</summary>
    [Theory]
    [InlineData(null)]
    [InlineData(652_282_293L)]
    [InlineData(652_282_295L)]
    public void AbsentOrDifferentSizeIsIncomplete(long? bytes) => Assert.False(Encoder.IsComplete(bytes));

    [Fact]
    public void ManifestTotalsTheModelSize()
    {
        Assert.Equal(["encoder.int8.onnx", "decoder.int8.onnx", "joiner.int8.onnx", "tokens.txt"],
            ParakeetModel.Files.Select(f => f.Name));
        Assert.Equal(670_576_784, ParakeetModel.Bytes);
    }

    /// <summary>A body longer than the manifest (wrong revision) fails its hash later; the menu still stops at 100%.</summary>
    [Theory]
    [InlineData(0L, "0%")]
    [InlineData(670_576_783L, "99%")]
    [InlineData(670_576_784L, "100%")]
    [InlineData(1_341_153_568L, "100%")]
    public void DownloadStatusTruncatesThePercent(long received, string percent) =>
        Assert.Equal($"Downloading model: {percent} of 671 MB", ParakeetModel.DownloadStatus(received, ParakeetModel.Bytes));
}
