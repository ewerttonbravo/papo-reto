/// The system pasteboard as the Core sees it; `Snapshot` holds every item the user had copied.
public protocol PasteboardPort {
    associatedtype Snapshot
    var changeCount: Int { get }
    func snapshot() -> Snapshot
    /// Writes text marked so that clipboard managers skip it (org.nspasteboard.TransientType).
    func writeTransient(_ text: String)
    func restore(_ snapshot: Snapshot)
}

public protocol KeyboardPort {
    func pressCmdV()
}

/// The clipboard the user had before a paste, to put back once the target app has read the text.
public struct PendingRestore<Snapshot> {
    let snapshot: Snapshot
    let changeCount: Int

    /// Skipped when someone wrote to the pasteboard after our text: their copy wins.
    public func restore<P: PasteboardPort>(on pasteboard: P) where P.Snapshot == Snapshot {
        guard pasteboard.changeCount == changeCount else { return }
        pasteboard.restore(snapshot)
    }
}

/// Pastes `text` at the cursor through the pasteboard, keeping what it held before.
public func paste<P: PasteboardPort>(
    _ text: String, pasteboard: P, keyboard: some KeyboardPort
) -> PendingRestore<P.Snapshot> {
    let previous = pasteboard.snapshot()
    pasteboard.writeTransient(text)
    let pending = PendingRestore(snapshot: previous, changeCount: pasteboard.changeCount)
    keyboard.pressCmdV()
    return pending
}
