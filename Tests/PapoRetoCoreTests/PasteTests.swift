import Testing
import PapoRetoCore

/// In-memory pasteboard whose snapshot is its list of items; keyboard calls land in the same log.
private final class FakePasteboard: PasteboardPort, KeyboardPort {
    var items: [String]
    var changeCount = 0
    var calls: [String] = []

    init(_ items: [String]) { self.items = items }

    func snapshot() -> [String] { calls.append("snapshot"); return items }
    func writeTransient(_ text: String) { calls.append("write \(text)"); items = [text]; changeCount += 1 }
    func restore(_ snapshot: [String]) { calls.append("restore"); items = snapshot; changeCount += 1 }
    func isConcealed(_ snapshot: [String]) -> Bool { snapshot.contains("password") }
    func pressCmdV() { calls.append("cmd+v") }
}

@Test func pasteWritesTheTextAsTransientBeforeCmdV() {
    let pasteboard = FakePasteboard(["copied before"])
    _ = paste("Bom dia.", pasteboard: pasteboard, keyboard: pasteboard)
    #expect(pasteboard.calls == ["snapshot", "write Bom dia.", "cmd+v"])
}

@Test func restoreBringsBackThePreviousClipboard() {
    let pasteboard = FakePasteboard(["copied before", "image"])
    let pending = paste("Bom dia.", pasteboard: pasteboard, keyboard: pasteboard)
    pending.restore(on: pasteboard)
    #expect(pasteboard.items == ["copied before", "image"])
}

@Test func restoreKeepsAClipboardChangedAfterThePaste() {
    let pasteboard = FakePasteboard(["copied before"])
    let pending = paste("Bom dia.", pasteboard: pasteboard, keyboard: pasteboard)
    pasteboard.items = ["copied by the user"]
    pasteboard.changeCount += 1
    pending.restore(on: pasteboard)
    #expect(pasteboard.items == ["copied by the user"])
}

@Test func restoreSkipsAConcealedClipboard() {
    let pasteboard = FakePasteboard(["password"])
    let pending = paste("Bom dia.", pasteboard: pasteboard, keyboard: pasteboard)
    pending.restore(on: pasteboard)
    #expect(pasteboard.items == ["Bom dia."])
}
