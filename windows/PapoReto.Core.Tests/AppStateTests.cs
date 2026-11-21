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

    static readonly AppState Loading = new();
    static readonly AppState RecordingWhileLoading = Loading with { Activity = AppState.ActivityState.Recording };
    static readonly AppState PendingWhileLoading = Loading with { Activity = AppState.ActivityState.Transcribing };

    [Fact]
    public void HotkeyPressedWhileLoadingStartsRecording()
    {
        var (next, effects) = Loading.Handling(new AppEvent.HotkeyPressed());
        Assert.Equal(RecordingWhileLoading, next);
        Assert.Equal(new[] { AppEffect.StartRecording }, effects);
    }

    [Fact]
    public void HotkeyReleasedWhileLoadingWaitsForTheModel()
    {
        var (next, effects) = RecordingWhileLoading.Handling(new AppEvent.HotkeyReleased(Ms(301)));
        Assert.Equal(PendingWhileLoading, next);
        Assert.Equal(new[] { AppEffect.StopRecording }, effects);
    }

    [Fact]
    public void ModelLoadedWithPendingAudioTranscribes()
    {
        var (next, effects) = PendingWhileLoading.Handling(new AppEvent.ModelLoaded());
        Assert.Equal(Transcribing, next);
        Assert.Equal(new[] { AppEffect.Transcribe }, effects);
    }

    [Theory]
    [InlineData(AppState.ActivityState.Recording)]
    [InlineData(AppState.ActivityState.Transcribing)]
    public void ModelFailedWithPendingAudioDiscardsIt(AppState.ActivityState activity)
    {
        var (next, effects) = (Loading with { Activity = activity }).Handling(new AppEvent.ModelFailed());
        Assert.Equal(new AppState { Model = AppState.ModelState.Unavailable }, next);
        Assert.Equal(new[] { AppEffect.DiscardRecording }, effects);
    }

    public static TheoryData<AppState> HotkeyIgnoredStates => new()
    {
        new AppState { Model = AppState.ModelState.Unavailable },
        Transcribing,
        PendingWhileLoading,
        // The keyboard's auto-repeat sends the key down again while it is held.
        Recording,
    };

    [Theory]
    [MemberData(nameof(HotkeyIgnoredStates))]
    public void HotkeyIgnoredWhenModelUnavailableTranscribingOrRecording(AppState state)
    {
        var (next, effects) = state.Handling(new AppEvent.HotkeyPressed());
        Assert.Equal(state, next);
        Assert.Empty(effects);
    }

    [Theory]
    [InlineData(AppState.ModelState.Ready)]
    [InlineData(AppState.ModelState.Loading)]
    public void RecordingFailedGoesBackToIdle(AppState.ModelState model)
    {
        var state = new AppState { Model = model };
        var (next, effects) = (state with { Activity = AppState.ActivityState.Recording }).Handling(new AppEvent.RecordingFailed());
        Assert.Equal(state, next);
        Assert.Empty(effects);
    }
}
