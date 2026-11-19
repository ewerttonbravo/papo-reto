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

@Test func shortAudioIsSkippedWithoutRunningTheDetector() {
    var asked = false
    let verdict = AppState.audioVerdict(sampleCount: 6399, sampleRate: 16000) { asked = true; return true }
    #expect(verdict == .tooShort)
    #expect(!asked)
}

@Test func audioWithoutSpeechIsSkipped() {
    #expect(AppState.audioVerdict(sampleCount: 6400, sampleRate: 16000) { false } == .noSpeech)
}

@Test func audioWithSpeechIsTranscribed() {
    #expect(AppState.audioVerdict(sampleCount: 6400, sampleRate: 16000) { true } == .transcribe)
}

/// No detector file (`swift run`, no bundle): never lose a dictation.
@Test func withoutADetectorAudioIsTranscribed() {
    #expect(AppState.audioVerdict(sampleCount: 6400, sampleRate: 16000, containsSpeech: nil) == .transcribe)
}
