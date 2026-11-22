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
    #expect(textToPaste("Bom dia, pessoal.", around: nil) == "Bom dia, pessoal. ")
}

@Test func dictationAfterACharacterStartsWithASpace() {
    #expect(textToPaste("Texto", around: TextAroundCursor(before: ".", after: nil)) == " Texto")
}

@Test(arguments: [Character(" "), "\n", "\t", nil])
func dictationAfterWhitespaceOrAtTheStartHasNoSpace(before: Character?) {
    #expect(textToPaste("Texto", around: TextAroundCursor(before: before, after: nil)) == "Texto")
}

@Test(arguments: [Character("m"), "É", "7"])
func dictationBeforeALetterOrNumberEndsWithASpace(after: Character) {
    #expect(textToPaste("Texto", around: TextAroundCursor(before: nil, after: after)) == "Texto ")
}
