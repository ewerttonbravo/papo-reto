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
}
