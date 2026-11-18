import Testing
import PapoRetoCore

@Test func savedMicrophoneIsUsedWhileConnected() {
    #expect(microphoneInUse(saved: "headset", connected: ["built-in", "headset"]) == "headset")
}
