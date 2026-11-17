import Testing
import PapoRetoCore

@Test func everyStateHasADistinctIcon() {
    let icons = AppState.allCases.map(\.iconName)
    #expect(!icons.contains(""))
    #expect(Set(icons).count == AppState.allCases.count)
}

@Test func modelLoadedWhileLoadingGoesReady() {
    #expect(AppState.loading.handling(.modelLoaded) == .ready)
}

@Test func modelFailedWhileLoadingGoesModelUnavailable() {
    #expect(AppState.loading.handling(.modelFailed) == .modelUnavailable)
}

@Test func modelEventsOutsideLoadingKeepTheState() {
    #expect(AppState.ready.handling(.modelFailed) == .ready)
    #expect(AppState.recording.handling(.modelLoaded) == .recording)
}
