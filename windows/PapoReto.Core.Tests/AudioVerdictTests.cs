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

    [Fact]
    public void ShortAudioIsSkippedWithoutRunningTheDetector()
    {
        var asked = false;
        var verdict = AppState.AudioVerdictOf(6399, 16000, () => asked = true);
        Assert.Equal(AudioVerdict.TooShort, verdict);
        Assert.False(asked);
    }

    [Fact]
    public void AudioWithoutSpeechIsSkipped() =>
        Assert.Equal(AudioVerdict.NoSpeech, AppState.AudioVerdictOf(6400, 16000, () => false));

    [Fact]
    public void AudioWithSpeechIsTranscribed() =>
        Assert.Equal(AudioVerdict.Transcribe, AppState.AudioVerdictOf(6400, 16000, () => true));

    /// <summary>No detector file (`dotnet run`, no build copy): never lose a dictation.</summary>
    [Fact]
    public void WithoutADetectorAudioIsTranscribed() =>
        Assert.Equal(AudioVerdict.Transcribe, AppState.AudioVerdictOf(6400, 16000, null));
}
