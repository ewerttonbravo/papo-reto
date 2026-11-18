import AppKit
import PapoRetoCore

/// NSPasteboard.general; the snapshot copies every item with every type, in the original order.
struct SystemPasteboard: PasteboardPort {
    private static let transient = NSPasteboard.PasteboardType("org.nspasteboard.TransientType")
    private let pasteboard = NSPasteboard.general

    var changeCount: Int { pasteboard.changeCount }

    func snapshot() -> [[(NSPasteboard.PasteboardType, Data)]] {
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

    func restore(_ snapshot: [[(NSPasteboard.PasteboardType, Data)]]) {
        let items = snapshot.map { types in
            let item = NSPasteboardItem()
            for (type, data) in types { item.setData(data, forType: type) }
            return item
        }
        pasteboard.clearContents()
        pasteboard.writeObjects(items)
    }
}

/// Synthetic Cmd+V to the focused app. Needs Accessibility, already granted for the Fn tap.
struct SystemKeyboard: KeyboardPort {
    /// kVK_ANSI_V; layouts that move V off this key (Dvorak) will not paste.
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
