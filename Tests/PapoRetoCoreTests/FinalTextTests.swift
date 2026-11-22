import Testing
import PapoRetoCore

@Test func finalTextTrimsTheEnds() {
    #expect(finalText(" Bom dia, pessoal.\n") == "Bom dia, pessoal.")
}

@Test(arguments: ["", "  \n\t"])
func blankTranscriptionHasNoFinalText(transcription: String) {
    #expect(finalText(transcription) == nil)
}

@Test func pastedDictationEndsWithOneSpace() {
    #expect(textToPaste("Bom dia, pessoal.") == "Bom dia, pessoal. ")
}
