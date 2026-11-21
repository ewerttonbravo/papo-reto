namespace PapoReto.Core.Tests;

public class AppStateTests
{
    [Fact]
    public void NewStateIsLoadingWithTheLoadingIcon()
    {
        var state = new AppState();
        Assert.Equal(AppState.ModelState.Loading, state.Model);
        Assert.Equal(TrayIcon.Loading, state.Icon);
    }

    [Fact]
    public void ModelLoadedWhileLoadingGoesReady()
    {
        var next = new AppState().Handling(AppEvent.ModelLoaded);
        Assert.Equal(AppState.ModelState.Ready, next.Model);
        Assert.Equal(TrayIcon.Ready, next.Icon);
    }
}
