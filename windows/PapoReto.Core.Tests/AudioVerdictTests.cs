namespace PapoReto.Core.Tests;

public class AudioVerdictTests
{
    [Theory]
    [InlineData(0)]
    [InlineData(6399)]
    public void AudioShorterThan400msIsNotTranscribed(int samples) =>
        Assert.False(AppState.IsLongEnough(samples, 16000));

    [Theory]
    [InlineData(6400)]
    [InlineData(6401)]
    public void AudioOf400msOrLongerIsTranscribed(int samples) =>
        Assert.True(AppState.IsLongEnough(samples, 16000));
}
