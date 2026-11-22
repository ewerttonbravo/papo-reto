import ApplicationServices
import OSLog
import PapoRetoCore

private let log = Logger(subsystem: "papo-reto", category: "accessibility")

/// The characters on each side of the cursor of the focused field, read over Accessibility: one
/// character per side, held only until the paste. A field that does not answer is nil.
enum CursorContext {
    /// The default waits up to 6 s on a hung app; a responsive one answers in a few ms.
    private static let timeout: Float = 0.1

    static func textAroundCursor() -> TextAroundCursor? {
        let start = ContinuousClock.now
        let around = read()
        let outcome = around == nil ? "unknown" : "known"
        log.info("text around cursor \(outcome, privacy: .public) in \(ContinuousClock.now - start, privacy: .public)")
        return around
    }

    private static func read() -> TextAroundCursor? {
        let system = AXUIElementCreateSystemWide()
        AXUIElementSetMessagingTimeout(system, timeout)
        guard let field: AXUIElement = value(of: kAXFocusedUIElementAttribute, in: system) else { return nil }
        AXUIElementSetMessagingTimeout(field, timeout)
        guard let selection: AXValue = value(of: kAXSelectedTextRangeAttribute, in: field) else { return nil }
        var range = CFRange()
        guard AXValueGetValue(selection, .cfRange, &range), range.location >= 0, range.length >= 0 else { return nil }
        var before: Character?
        if range.location > 0 {
            // Two UTF-16 units, so an emoji before the cursor comes whole; the last character is the one.
            let length = min(2, range.location)
            guard let text = string(in: CFRange(location: range.location - length, length: length), of: field)
            else { return nil }
            before = text.last
        }
        // The paste replaces the selection, so what follows it is what the text will touch. Past the
        // end of the field the read fails, which is the same as nothing after.
        let after = string(in: CFRange(location: range.location + range.length, length: 1), of: field)?.first
        return TextAroundCursor(before: before, after: after)
    }

    /// Nil when the field fails or answers with more than was asked, so a wrong character never decides.
    private static func string(in range: CFRange, of field: AXUIElement) -> String? {
        var range = range
        var text: CFTypeRef?
        guard let parameter = AXValueCreate(.cfRange, &range),
              AXUIElementCopyParameterizedAttributeValue(
                  field, kAXStringForRangeParameterizedAttribute as CFString, parameter, &text) == .success,
              let text = text as? String, !text.isEmpty, text.utf16.count <= range.length
        else { return nil }
        return text
    }

    private static func value<T>(of attribute: String, in element: AXUIElement) -> T? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success else { return nil }
        return value as? T
    }
}
