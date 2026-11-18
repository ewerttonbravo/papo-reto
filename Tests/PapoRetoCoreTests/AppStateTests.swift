import Testing
import PapoRetoCore

private let ready = AppState(model: .ready)
private let recording = AppState(model: .ready, activity: .recording)
private let transcribing = AppState(model: .ready, activity: .transcribing)

@Test func everyStateHasADistinctIcon() {
    let shown = [AppState(), ready, AppState(model: .unavailable), recording, transcribing]
    let icons = shown.map(\.iconName)
    #expect(!icons.contains(""))
    #expect(Set(icons).count == shown.count)
}

@Test func modelLoadedWhileLoadingGoesReady() {
    let (state, effects) = AppState().handling(.modelLoaded)
    #expect(state == ready)
    #expect(effects.isEmpty)
}

@Test func modelFailedWhileLoadingGoesModelUnavailable() {
    let (state, effects) = AppState().handling(.modelFailed)
    #expect(state == AppState(model: .unavailable))
    #expect(effects.isEmpty)
}

@Test func modelEventsOutsideLoadingKeepTheState() {
    #expect(ready.handling(.modelFailed).state == ready)
    #expect(recording.handling(.modelLoaded).state == recording)
}

@Test func fnPressedWhenReadyStartsRecording() {
    let (state, effects) = ready.handling(.fnPressed)
    #expect(state == recording)
    #expect(effects == [.startRecording])
}

@Test func fnHeldOver300msStopsAndTranscribes() {
    let (state, effects) = recording.handling(.fnReleased(heldFor: .milliseconds(301)))
    #expect(state == transcribing)
    #expect(effects == [.stopRecording, .transcribe])
}

@Test(arguments: [299, 300])
func fnHeldUpTo300msDiscardsTheRecording(ms: Int) {
    let (state, effects) = recording.handling(.fnReleased(heldFor: .milliseconds(ms)))
    #expect(state == ready)
    #expect(effects == [.discardRecording])
}

@Test func transcribedGoesBackToIdle() {
    let (state, effects) = transcribing.handling(.transcribed)
    #expect(state == ready)
    #expect(effects.isEmpty)
}
