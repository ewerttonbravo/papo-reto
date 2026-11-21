namespace PapoReto.Core.Tests;

public class AppStateTests
{
    static readonly AppState Ready = new() { Model = AppState.ModelState.Ready };
    static readonly AppState Recording = Ready with { Activity = AppState.ActivityState.Recording };
    static readonly AppState Transcribing = Ready with { Activity = AppState.ActivityState.Transcribing };

    static TimeSpan Ms(int ms) => TimeSpan.FromMilliseconds(ms);

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
        var (next, effects) = new AppState().Handling(new AppEvent.ModelLoaded());
        Assert.Equal(Ready, next);
        Assert.Equal(TrayIcon.Ready, next.Icon);
        Assert.Empty(effects);
    }

    [Fact]
    public void ModelFailedWhileLoadingGoesModelUnavailable()
    {
        var (next, effects) = new AppState().Handling(new AppEvent.ModelFailed());
        Assert.Equal(AppState.ModelState.Unavailable, next.Model);
        Assert.Equal(TrayIcon.Unavailable, next.Icon);
        Assert.Empty(effects);
    }

    [Fact]
    public void EveryStateHasADistinctIcon()
    {
        var shown = new[] { new AppState(), Ready, new AppState { Model = AppState.ModelState.Unavailable }, Recording, Transcribing };
        Assert.Equal(shown.Length, shown.Select(s => s.Icon).Distinct().Count());
    }

    public static TheoryData<AppState.ModelState, AppEvent> ModelEventsOutsideLoading => new()
    {
        { AppState.ModelState.Ready, new AppEvent.ModelFailed() },
        { AppState.ModelState.Ready, new AppEvent.ModelLoaded() },
        { AppState.ModelState.Unavailable, new AppEvent.ModelLoaded() },
        { AppState.ModelState.Unavailable, new AppEvent.ModelFailed() },
    };

    [Theory]
    [MemberData(nameof(ModelEventsOutsideLoading))]
    public void ModelEventsOutsideLoadingKeepTheState(AppState.ModelState model, AppEvent e)
    {
        var state = new AppState { Model = model };
        var (next, effects) = state.Handling(e);
        Assert.Equal(state, next);
        Assert.Empty(effects);
    }

    [Fact]
    public void HotkeyPressedWhenReadyStartsRecording()
    {
        var (next, effects) = Ready.Handling(new AppEvent.HotkeyPressed());
        Assert.Equal(Recording, next);
        Assert.Equal(TrayIcon.Listening, next.Icon);
        Assert.Equal(new[] { AppEffect.StartRecording }, effects);
    }

    [Fact]
    public void HotkeyHeldOver300msStopsAndTranscribes()
    {
        var (next, effects) = Recording.Handling(new AppEvent.HotkeyReleased(Ms(301)));
        Assert.Equal(Transcribing, next);
        Assert.Equal(TrayIcon.Thinking, next.Icon);
        Assert.Equal(new[] { AppEffect.StopRecording, AppEffect.Transcribe }, effects);
    }

    [Theory]
    [InlineData(299)]
    [InlineData(300)]
    public void HotkeyHeldUpTo300msDiscardsTheRecording(int heldMs)
    {
        var (next, effects) = Recording.Handling(new AppEvent.HotkeyReleased(Ms(heldMs)));
        Assert.Equal(Ready, next);
        Assert.Equal(new[] { AppEffect.DiscardRecording }, effects);
    }

    [Fact]
    public void TranscribedGoesBackToIdle()
    {
        var (next, effects) = Transcribing.Handling(new AppEvent.Transcribed());
        Assert.Equal(Ready, next);
        Assert.Empty(effects);
    }
}
