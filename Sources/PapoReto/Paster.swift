import AppKit
import PapoRetoCore

/// NSPasteboard.general; the snapshot copies every item with every type, in the original order.
struct SystemPasteboard: PasteboardPort {
    typealias Snapshot = [[(NSPasteboard.PasteboardType, Data)]]
    private static let transient = NSPasteboard.PasteboardType("org.nspasteboard.TransientType")
    private static let concealed = NSPasteboard.PasteboardType("org.nspasteboard.ConcealedType")
    private let pasteboard = NSPasteboard.general

    var changeCount: Int { pasteboard.changeCount }

    func snapshot() -> Snapshot {
        (pasteboard.pasteboardItems ?? []).map { item in
            item.types.compactMap { type in item.data(forType: type).map { (type, $0) } }
        }
    }

    func writeTransient(_ text: String) {
        let item = NSPasteboardItem()
        item.setString(text, forType: .string)
        item.setData(Data(), forType: Self.transient)
        pasteboard.clearContents()
        pasteboard.writeObjects([item])
    }

    func restore(_ snapshot: Snapshot) {
        let items = snapshot.map { types in
            let item = NSPasteboardItem()
            for (type, data) in types { item.setData(data, forType: type) }
            return item
        }
        pasteboard.clearContents()
        pasteboard.writeObjects(items)
    }

    func isConcealed(_ snapshot: Snapshot) -> Bool {
        snapshot.contains { types in types.contains { $0.0 == Self.concealed } }
    }
}

/// Synthetic Cmd+V to the focused app. Needs Accessibility, already granted for the Fn tap.
struct SystemKeyboard: KeyboardPort {
    /// kVK_ANSI_V. Layouts that move V off this key send another shortcut: Dvorak gets Cmd+K.
    private static let vKey: CGKeyCode = 9

    func pressCmdV() {
        let source = CGEventSource(stateID: .combinedSessionState)
        for keyDown in [true, false] {
            let event = CGEvent(keyboardEventSource: source, virtualKey: Self.vKey, keyDown: keyDown)
            event?.flags = .maskCommand
            event?.post(tap: .cghidEventTap)
        }
    }
}
