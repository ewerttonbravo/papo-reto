import Testing
import PapoRetoCore

@Test(arguments: [0, 6399])
func audioShorterThan400msIsNotTranscribed(samples: Int) {
    #expect(!AppState.isLongEnough(sampleCount: samples, sampleRate: 16000))
}

@Test(arguments: [6400, 6401])
func audioOf400msOrLongerIsTranscribed(samples: Int) {
    #expect(AppState.isLongEnough(sampleCount: samples, sampleRate: 16000))
}
