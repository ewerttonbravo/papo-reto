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

public class TaskbarInkTests
{
    [Fact]
    public void LightThemeValueMeansALightTaskbar() =>
        Assert.True(TrayIcons.LightTaskbar(highContrast: false, contrastBackgroundIsLight: false, systemUsesLightTheme: 1));

    [Theory]
    [InlineData(0)]
    [InlineData(null)]
    public void DarkOrAbsentThemeValueMeansADarkTaskbar(int? value) =>
        Assert.False(TrayIcons.LightTaskbar(highContrast: false, contrastBackgroundIsLight: true, systemUsesLightTheme: value));

    [Fact]
    public void ContrastThemeFollowsItsOwnBackgroundOverTheThemeValue()
    {
        Assert.False(TrayIcons.LightTaskbar(highContrast: true, contrastBackgroundIsLight: false, systemUsesLightTheme: 1));
        Assert.True(TrayIcons.LightTaskbar(highContrast: true, contrastBackgroundIsLight: true, systemUsesLightTheme: 0));
    }
}
