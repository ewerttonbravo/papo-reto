import Testing
import PapoRetoCore

@Test func historyListsTheNewestDictationFirst() {
    var history = DictationHistory()
    history.add("Bom dia.")
    history.add("Boa tarde.")
    #expect(history.entries == ["Boa tarde.", "Bom dia."])
}

@Test func eleventhDictationDropsTheOldest() {
    var history = DictationHistory()
    for n in 1...11 { history.add("Ditado \(n)") }
    #expect(history.entries == (2...11).reversed().map { "Ditado \($0)" })
}

@Test func tenDictationsAreAllKept() {
    var history = DictationHistory()
    for n in 1...10 { history.add("Ditado \(n)") }
    #expect(history.entries == (1...10).reversed().map { "Ditado \($0)" })
}
