import Foundation

/// The text that goes to the user; nil means there is nothing to deliver.
public func finalText(_ transcription: String) -> String? {
    let text = transcription.trimmingCharacters(in: .whitespacesAndNewlines)
    return text.isEmpty ? nil : text
}

/// The characters next to the cursor in the focused field: nil before at its start, nil after at
/// its end or when that side does not answer.
public struct TextAroundCursor: Sendable {
    public let before: Character?
    public let after: Character?

    public init(before: Character?, after: Character?) {
        self.before = before
        self.after = after
    }
}

/// What goes to the cursor: a space before when the text would stick to a word. A field that
/// cannot be read (nil) gets one at the end instead, so the next dictation does not stick to this one.
public func textToPaste(_ text: String, around: TextAroundCursor?) -> String {
    guard let around else { return text + " " }
    let leading = around.before.map { !$0.isWhitespace } ?? false
    let trailing = around.after.map { $0.isLetter || $0.isNumber } ?? false
    return (leading ? " " : "") + text + (trailing ? " " : "")
}
