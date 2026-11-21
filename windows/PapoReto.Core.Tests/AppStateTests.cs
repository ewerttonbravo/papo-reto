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

    [Fact]
    public void ModelFailedWhileLoadingGoesModelUnavailable()
    {
        var next = new AppState().Handling(AppEvent.ModelFailed);
        Assert.Equal(AppState.ModelState.Unavailable, next.Model);
        Assert.Equal(TrayIcon.Unavailable, next.Icon);
    }

    [Fact]
    public void EveryStateHasADistinctIcon()
    {
        var icons = Enum.GetValues<AppState.ModelState>().Select(m => new AppState { Model = m }.Icon);
        Assert.Equal(Enum.GetValues<AppState.ModelState>().Length, icons.Distinct().Count());
    }

    [Theory]
    [InlineData(AppState.ModelState.Ready, AppEvent.ModelFailed)]
    [InlineData(AppState.ModelState.Ready, AppEvent.ModelLoaded)]
    [InlineData(AppState.ModelState.Unavailable, AppEvent.ModelLoaded)]
    [InlineData(AppState.ModelState.Unavailable, AppEvent.ModelFailed)]
    public void ModelEventsOutsideLoadingKeepTheState(AppState.ModelState model, AppEvent e)
    {
        var state = new AppState { Model = model };
        Assert.Equal(state, state.Handling(e));
    }
}
