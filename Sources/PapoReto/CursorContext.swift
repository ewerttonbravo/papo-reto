import ApplicationServices
import OSLog
import PapoRetoCore

private let log = Logger(subsystem: "papo-reto", category: "accessibility")

/// The character before the cursor of the focused field, read over Accessibility: one character,
/// held only until the paste. A field that does not answer is unknown.
enum CursorContext {
    /// The default waits up to 6 s on a hung app; a responsive one answers in a few ms.
    private static let timeout: Float = 0.1

    static func textBeforeCursor() -> TextBeforeCursor {
        let start = ContinuousClock.now
        let before = read()
        let outcome: String
        if case .unknown = before { outcome = "unknown" } else { outcome = "known" }
        log.info("text before cursor \(outcome, privacy: .public) in \(ContinuousClock.now - start, privacy: .public)")
        return before
    }

    private static func read() -> TextBeforeCursor {
        let system = AXUIElementCreateSystemWide()
        AXUIElementSetMessagingTimeout(system, timeout)
        guard let field: AXUIElement = value(of: kAXFocusedUIElementAttribute, in: system) else { return .unknown }
        AXUIElementSetMessagingTimeout(field, timeout)
        guard let selection: AXValue = value(of: kAXSelectedTextRangeAttribute, in: field) else { return .unknown }
        var range = CFRange()
        guard AXValueGetValue(selection, .cfRange, &range), range.location >= 0 else { return .unknown }
        if range.location == 0 { return .nothing }
        var previous = CFRange(location: range.location - 1, length: 1)
        var text: CFTypeRef?
        guard let parameter = AXValueCreate(.cfRange, &previous),
              AXUIElementCopyParameterizedAttributeValue(
                  field, kAXStringForRangeParameterizedAttribute as CFString, parameter, &text) == .success,
              let character = (text as? String)?.first
        else { return .unknown }
        return .character(character)
    }

    private static func value<T>(of attribute: String, in element: AXUIElement) -> T? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success else { return nil }
        return value as? T
    }
}
