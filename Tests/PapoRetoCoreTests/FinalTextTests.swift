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
    #expect(textToPaste("Bom dia, pessoal.", after: .unknown) == "Bom dia, pessoal. ")
}

@Test func dictationAfterACharacterStartsWithASpace() {
    #expect(textToPaste("Texto", after: .character(".")) == " Texto")
}

@Test(arguments: [TextBeforeCursor.character(" "), .character("\n"), .character("\t"), .nothing])
func dictationAfterWhitespaceOrAtTheStartHasNoSpace(before: TextBeforeCursor) {
    #expect(textToPaste("Texto", after: before) == "Texto")
}
