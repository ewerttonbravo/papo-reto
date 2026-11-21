namespace PapoReto.Core.Tests;

public class FinalTextTests
{
    [Fact]
    public void FinalTextTrimsTheEnds() =>
        Assert.Equal("Olá, mundo.", FinalText.Of(" \n Olá, mundo.\t\r\n"));

    [Theory]
    [InlineData("")]
    [InlineData(" \n\t ")]
    public void BlankTranscriptionHasNoFinalText(string transcription) =>
        Assert.Null(FinalText.Of(transcription));
}
