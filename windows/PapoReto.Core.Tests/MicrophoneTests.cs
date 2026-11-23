namespace PapoReto.Core.Tests;

public class MicrophoneTests
{
    [Fact]
    public void SavedMicrophoneIsUsedWhileConnected() =>
        Assert.Equal("headset", Microphone.InUse("headset", ["built-in", "headset"]));

    [Fact]
    public void SavedMicrophoneThatDisappearedFallsBackToDefault() =>
        Assert.Null(Microphone.InUse("headset", ["built-in"]));

    [Fact]
    public void NoSavedMicrophoneFollowsTheDefault() =>
        Assert.Null(Microphone.InUse(null, ["built-in", "headset"]));
}
