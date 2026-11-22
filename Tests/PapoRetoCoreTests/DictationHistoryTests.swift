import Testing
import PapoRetoCore

@Test func historyListsTheNewestDictationFirst() {
    var history = DictationHistory()
    history.add("Bom dia.")
    history.add("Boa tarde.")
    #expect(history.entries == ["Boa tarde.", "Bom dia."])
}
