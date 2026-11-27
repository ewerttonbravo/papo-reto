namespace PapoReto.Core.Tests;

public class TrayIconsTests
{
    [Fact]
    public void DarkTaskbarGetsEachStatesWhiteProfile()
    {
        Assert.Equal("tray-ready-white.ico", TrayIcons.FileFor(TrayIcon.Ready, lightTaskbar: false));
        Assert.Equal("tray-listening-white.ico", TrayIcons.FileFor(TrayIcon.Listening, lightTaskbar: false));
        Assert.Equal("tray-thinking-white.ico", TrayIcons.FileFor(TrayIcon.Thinking, lightTaskbar: false));
    }

    [Fact]
    public void LightTaskbarGetsEachStatesBlackProfile()
    {
        Assert.Equal("tray-ready-black.ico", TrayIcons.FileFor(TrayIcon.Ready, lightTaskbar: true));
        Assert.Equal("tray-listening-black.ico", TrayIcons.FileFor(TrayIcon.Listening, lightTaskbar: true));
        Assert.Equal("tray-thinking-black.ico", TrayIcons.FileFor(TrayIcon.Thinking, lightTaskbar: true));
    }

    [Theory]
    [InlineData(TrayIcon.Loading)]
    [InlineData(TrayIcon.Downloading)]
    [InlineData(TrayIcon.Unavailable)]
    public void LoadingDownloadingAndUnavailableKeepTheSystemIcon(TrayIcon icon)
    {
        Assert.Null(TrayIcons.FileFor(icon, lightTaskbar: false));
        Assert.Null(TrayIcons.FileFor(icon, lightTaskbar: true));
    }
}
