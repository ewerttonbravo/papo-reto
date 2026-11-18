import Testing
import PapoRetoCore

private let ready = AppState(model: .ready)
private let recording = AppState(model: .ready, activity: .recording)
private let transcribing = AppState(model: .ready, activity: .transcribing)
private let handsFree = AppState(model: .ready, activity: .handsFree)
private let afterTap = AppState(model: .ready, afterTap: true)

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
    let (state, effects) = ready.handling(.fnPressed(sinceRelease: nil))
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
    #expect(state == afterTap)
    #expect(effects == [.discardRecording])
}

@Test func fnPressedUnder400msAfterATapStartsHandsFree() {
    let (state, effects) = afterTap.handling(.fnPressed(sinceRelease: .milliseconds(399)))
    #expect(state == handsFree)
    #expect(state.iconName == recording.iconName)
    #expect(effects == [.startRecording])
}

@Test func fnPressedFrom400msAfterATapStartsPushToTalk() {
    let (state, effects) = afterTap.handling(.fnPressed(sinceRelease: .milliseconds(400)))
    #expect(state == recording)
    #expect(effects == [.startRecording])
}

@Test func quickPressWithoutATapStartsPushToTalk() {
    let (state, effects) = ready.handling(.fnPressed(sinceRelease: .milliseconds(100)))
    #expect(state == recording)
    #expect(effects == [.startRecording])
}

@Test func fnPressedInHandsFreeStopsAndTranscribes() {
    let (state, effects) = handsFree.handling(.fnPressed(sinceRelease: .seconds(5)))
    #expect(state == transcribing)
    #expect(effects == [.stopRecording, .transcribe])
}

@Test func fnPressedInHandsFreeWhileLoadingWaitsForTheModel() {
    let (state, effects) = AppState(model: .loading, activity: .handsFree).handling(.fnPressed(sinceRelease: .seconds(5)))
    #expect(state == AppState(model: .loading, activity: .transcribing))
    #expect(effects == [.stopRecording])
}

@Test(arguments: [100, 300])
func fnTappedInHandsFreeKeepsRecording(ms: Int) {
    let (state, effects) = handsFree.handling(.fnReleased(heldFor: .milliseconds(ms)))
    #expect(state == handsFree)
    #expect(effects.isEmpty)
}

@Test func fnHeldOver300msInHandsFreeStopsAndTranscribes() {
    let (state, effects) = handsFree.handling(.fnReleased(heldFor: .milliseconds(301)))
    #expect(state == transcribing)
    #expect(effects == [.stopRecording, .transcribe])
}

@Test func transcribedWithFootprintUnder900MBKeepsTheModel() {
    let (state, effects) = transcribing.handling(.transcribed(footprintMB: 899.9))
    #expect(state == ready)
    #expect(effects.isEmpty)
}

@Test(arguments: [900, 1005])
func transcribedWithFootprintFrom900MBReloadsTheModel(footprintMB: Double) {
    let (state, effects) = transcribing.handling(.transcribed(footprintMB: footprintMB))
    #expect(state == AppState(model: .loading))
    #expect(effects == [.reloadModel])
}

@Test func fnPressedWhileLoadingStartsRecording() {
    let (state, effects) = AppState().handling(.fnPressed(sinceRelease: nil))
    #expect(state == AppState(model: .loading, activity: .recording))
    #expect(state.iconName == recording.iconName)
    #expect(effects == [.startRecording])
}

@Test func fnReleasedWhileLoadingWaitsForTheModel() {
    let (state, effects) = AppState(model: .loading, activity: .recording)
        .handling(.fnReleased(heldFor: .milliseconds(301)))
    #expect(state == AppState(model: .loading, activity: .transcribing))
    #expect(effects == [.stopRecording])
}

@Test func modelLoadedWithPendingAudioTranscribes() {
    let (state, effects) = AppState(model: .loading, activity: .transcribing).handling(.modelLoaded)
    #expect(state == transcribing)
    #expect(effects == [.transcribe])
}

@Test(arguments: [AppState.Activity.recording, .transcribing])
func modelFailedWithPendingAudioDiscardsIt(activity: AppState.Activity) {
    let (state, effects) = AppState(model: .loading, activity: activity).handling(.modelFailed)
    #expect(state == AppState(model: .unavailable))
    #expect(effects == [.discardRecording])
}

@Test(arguments: [AppState(model: .unavailable), transcribing])
func fnIgnoredWhenModelUnavailableOrTranscribing(state: AppState) {
    let (next, effects) = state.handling(.fnPressed(sinceRelease: nil))
    #expect(next == state)
    #expect(effects.isEmpty)
}

@Test(arguments: [recording, handsFree])
func recordingLimitStopsTranscribesAndAlerts(state: AppState) {
    let (state, effects) = state.handling(.recordingLimitReached)
    #expect(state == transcribing)
    #expect(effects == [.stopRecording, .alertRecordingLimit, .transcribe])
}

@Test func recordingLimitWhileLoadingWaitsForTheModel() {
    let (state, effects) = AppState(model: .loading, activity: .recording).handling(.recordingLimitReached)
    #expect(state == AppState(model: .loading, activity: .transcribing))
    #expect(effects == [.stopRecording, .alertRecordingLimit])
}

@Test(arguments: [ready, transcribing])
func recordingLimitOutsideRecordingIsIgnored(state: AppState) {
    let (next, effects) = state.handling(.recordingLimitReached)
    #expect(next == state)
    #expect(effects.isEmpty)
}

@Test func fnReleasedAfterTheLimitIsIgnored() {
    let (state, effects) = transcribing.handling(.fnReleased(heldFor: .seconds(125)))
    #expect(state == transcribing)
    #expect(effects.isEmpty)
}

@Test(arguments: [false, true])
func keyWhileHoldingFnCancels(isEscape: Bool) {
    let (state, effects) = AppState(model: .loading, activity: .recording).handling(.keyPressed(isEscape: isEscape))
    #expect(state == AppState(model: .loading))
    #expect(effects == [.discardRecording])
}

@Test func escInHandsFreeCancels() {
    let (state, effects) = handsFree.handling(.keyPressed(isEscape: true))
    #expect(state == ready)
    #expect(effects == [.discardRecording])
}

@Test func typingInHandsFreeKeepsRecording() {
    let (state, effects) = handsFree.handling(.keyPressed(isEscape: false))
    #expect(state == handsFree)
    #expect(effects.isEmpty)
}

@Test(arguments: [ready, afterTap, transcribing, AppState()])
func escOutsideRecordingIsIgnored(state: AppState) {
    let (next, effects) = state.handling(.keyPressed(isEscape: true))
    #expect(next == state)
    #expect(effects.isEmpty)
}
