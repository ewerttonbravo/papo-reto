import Testing
import PapoRetoCore

@Test func savedMicrophoneIsUsedWhileConnected() {
    #expect(microphoneInUse(saved: "headset", connected: ["built-in", "headset"]) == "headset")
}

@Test func savedMicrophoneThatDisappearedFallsBackToDefault() {
    #expect(microphoneInUse(saved: "headset", connected: ["built-in"]) == nil)
}
