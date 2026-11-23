namespace PapoReto.Core.Tests;

public class AppStateTests
{
    static readonly AppState Ready = new() { Model = AppState.ModelState.Ready };
    static readonly AppState Recording = Ready with { Activity = AppState.ActivityState.Recording };
    static readonly AppState Transcribing = Ready with { Activity = AppState.ActivityState.Transcribing };
    static readonly AppState HandsFree = Ready with { Activity = AppState.ActivityState.HandsFree };
    // AltGr still down from the double tap's second press.
    static readonly AppState HandsFreeHeld = Ready with { Activity = AppState.ActivityState.HandsFreeHeld };
    static readonly AppState AfterTap = Ready with { AfterTap = true };

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
        var (next, effects) = Ready.Handling(new AppEvent.HotkeyPressed(SinceRelease: null));
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
        Assert.Equal(AfterTap, next);
        Assert.Equal(new[] { AppEffect.DiscardRecording }, effects);
    }

    [Fact]
    public void HotkeyPressedUnder400msAfterATapStartsHandsFree()
    {
        var (next, effects) = AfterTap.Handling(new AppEvent.HotkeyPressed(Ms(399)));
        Assert.Equal(HandsFreeHeld, next);
        Assert.Equal(TrayIcon.Listening, next.Icon);
        Assert.Equal(new[] { AppEffect.StartRecording }, effects);
    }

    [Fact]
    public void HotkeyPressedFrom400msAfterATapStartsPushToTalk()
    {
        var (next, effects) = AfterTap.Handling(new AppEvent.HotkeyPressed(Ms(400)));
        Assert.Equal(Recording, next);
        Assert.Equal(new[] { AppEffect.StartRecording }, effects);
    }

    [Fact]
    public void QuickPressWithoutATapStartsPushToTalk()
    {
        var (next, effects) = Ready.Handling(new AppEvent.HotkeyPressed(Ms(100)));
        Assert.Equal(Recording, next);
        Assert.Equal(new[] { AppEffect.StartRecording }, effects);
    }

    [Fact]
    public void HotkeyPressedInHandsFreeStopsAndTranscribes()
    {
        var (next, effects) = HandsFree.Handling(new AppEvent.HotkeyPressed(TimeSpan.FromSeconds(5)));
        Assert.Equal(Transcribing, next);
        Assert.Equal(new[] { AppEffect.StopRecording, AppEffect.Transcribe }, effects);
    }

    [Fact]
    public void HotkeyPressedInHandsFreeWhileLoadingWaitsForTheModel()
    {
        var state = new AppState { Activity = AppState.ActivityState.HandsFree };
        var (next, effects) = state.Handling(new AppEvent.HotkeyPressed(TimeSpan.FromSeconds(5)));
        Assert.Equal(new AppState { Activity = AppState.ActivityState.Transcribing }, next);
        Assert.Equal(new[] { AppEffect.StopRecording }, effects);
    }

    [Theory]
    [InlineData(100)]
    [InlineData(300)]
    public void HotkeyTappedInHandsFreeKeepsRecording(int heldMs)
    {
        var (next, effects) = HandsFreeHeld.Handling(new AppEvent.HotkeyReleased(Ms(heldMs)));
        Assert.Equal(HandsFree, next);
        Assert.Equal(TrayIcon.Listening, next.Icon);
        Assert.Empty(effects);
    }

    /// <summary>A tap then a hold to talk: the hold's release ends it like push-to-talk.</summary>
    [Fact]
    public void HotkeyHeldOver300msInHandsFreeStopsAndTranscribes()
    {
        var (next, effects) = HandsFreeHeld.Handling(new AppEvent.HotkeyReleased(Ms(301)));
        Assert.Equal(Transcribing, next);
        Assert.Equal(new[] { AppEffect.StopRecording, AppEffect.Transcribe }, effects);
    }

    [Fact]
    public void TranscribedBelowTheMemoryLimitGoesBackToIdle()
    {
        var (next, effects) = Transcribing.Handling(new AppEvent.Transcribed(PrivateMB: 1_299.9));
        Assert.Equal(Ready, next);
        Assert.Empty(effects);
    }

    [Fact]
    public void TranscribedAtTheMemoryLimitReloadsTheModel()
    {
        var (next, effects) = Transcribing.Handling(new AppEvent.Transcribed(PrivateMB: 1_300));
        Assert.Equal(new AppState(), next);
        Assert.Equal(TrayIcon.Loading, next.Icon);
        Assert.Equal(new[] { AppEffect.ReloadModel }, effects);
    }

    static readonly AppState Loading = new();
    static readonly AppState RecordingWhileLoading = Loading with { Activity = AppState.ActivityState.Recording };
    static readonly AppState PendingWhileLoading = Loading with { Activity = AppState.ActivityState.Transcribing };

    [Fact]
    public void HotkeyPressedWhileLoadingStartsRecording()
    {
        var (next, effects) = Loading.Handling(new AppEvent.HotkeyPressed(SinceRelease: null));
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
        var (next, effects) = state.Handling(new AppEvent.HotkeyPressed(SinceRelease: null));
        Assert.Equal(state, next);
        Assert.Empty(effects);
    }

    public static TheoryData<AppState> RecordingStates => new() { Recording, HandsFreeHeld, HandsFree };

    [Theory]
    [MemberData(nameof(RecordingStates))]
    public void RecordingLimitStopsAndTranscribes(AppState state)
    {
        var (next, effects) = state.Handling(new AppEvent.RecordingLimitReached());
        Assert.Equal(Transcribing, next);
        Assert.Equal(new[] { AppEffect.StopRecording, AppEffect.Transcribe }, effects);
    }

    [Fact]
    public void RecordingLimitWhileLoadingWaitsForTheModel()
    {
        var (next, effects) = RecordingWhileLoading.Handling(new AppEvent.RecordingLimitReached());
        Assert.Equal(PendingWhileLoading, next);
        Assert.Equal(new[] { AppEffect.StopRecording }, effects);
    }

    public static TheoryData<AppState> NotRecording => new() { Ready, Transcribing };

    [Theory]
    [MemberData(nameof(NotRecording))]
    public void RecordingLimitOutsideRecordingIsIgnored(AppState state)
    {
        var (next, effects) = state.Handling(new AppEvent.RecordingLimitReached());
        Assert.Equal(state, next);
        Assert.Empty(effects);
    }

    [Fact]
    public void HotkeyReleasedAfterTheLimitDoesNothing()
    {
        var (afterLimit, _) = Recording.Handling(new AppEvent.RecordingLimitReached());
        var (next, effects) = afterLimit.Handling(new AppEvent.HotkeyReleased(Ms(130_000)));
        Assert.Equal(Transcribing, next);
        Assert.Empty(effects);
    }

    /// <summary>Recording means AltGr is held, so any key but a modifier is a combination: it never dictates.</summary>
    [Theory]
    [InlineData(false)]
    [InlineData(true)]
    public void KeyWhileHoldingHotkeyCancels(bool isEscape)
    {
        var (next, effects) = RecordingWhileLoading.Handling(new AppEvent.KeyPressed(isEscape));
        Assert.Equal(Loading, next);
        Assert.Equal(new[] { AppEffect.DiscardRecording }, effects);
    }

    /// <summary>A stray tap then AltGr+Q to type "/" on ABNT2 must not leave a silent hands-free running.</summary>
    [Fact]
    public void KeyBeforeReleasingTheDoubleTapCancels()
    {
        var (next, effects) = HandsFreeHeld.Handling(new AppEvent.KeyPressed(IsEscape: false));
        Assert.Equal(Ready, next);
        Assert.Equal(new[] { AppEffect.DiscardRecording }, effects);
    }

    [Fact]
    public void EscInHandsFreeCancels()
    {
        var (next, effects) = HandsFree.Handling(new AppEvent.KeyPressed(IsEscape: true));
        Assert.Equal(Ready, next);
        Assert.Equal(new[] { AppEffect.DiscardRecording }, effects);
    }

    [Fact]
    public void TypingInHandsFreeKeepsRecording()
    {
        var (next, effects) = HandsFree.Handling(new AppEvent.KeyPressed(IsEscape: false));
        Assert.Equal(HandsFree, next);
        Assert.Empty(effects);
    }

    public static TheoryData<AppState> EscIgnoredStates => new() { Ready, AfterTap, Transcribing, Loading };

    [Theory]
    [MemberData(nameof(EscIgnoredStates))]
    public void EscOutsideRecordingIsIgnored(AppState state)
    {
        var (next, effects) = state.Handling(new AppEvent.KeyPressed(IsEscape: true));
        Assert.Equal(state, next);
        Assert.Empty(effects);
    }

    [Theory]
    [InlineData(AppState.ModelState.Ready, AppState.ActivityState.Recording)]
    [InlineData(AppState.ModelState.Loading, AppState.ActivityState.Recording)]
    [InlineData(AppState.ModelState.Ready, AppState.ActivityState.HandsFreeHeld)]
    [InlineData(AppState.ModelState.Ready, AppState.ActivityState.HandsFree)]
    public void RecordingFailedGoesBackToIdle(AppState.ModelState model, AppState.ActivityState activity)
    {
        var state = new AppState { Model = model };
        var (next, effects) = (state with { Activity = activity }).Handling(new AppEvent.RecordingFailed());
        Assert.Equal(state, next);
        Assert.Empty(effects);
    }
}
