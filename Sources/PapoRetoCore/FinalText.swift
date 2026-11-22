import Foundation

/// The text that goes to the user; nil means there is nothing to deliver.
public func finalText(_ transcription: String) -> String? {
    let text = transcription.trimmingCharacters(in: .whitespacesAndNewlines)
    return text.isEmpty ? nil : text
}

/// What precedes the cursor in the focused field; unknown when the field does not answer.
public enum TextBeforeCursor: Sendable {
    case unknown
    case nothing
    case character(Character)
}

/// What goes to the cursor: a space before when the text would stick to a word. A field that
/// cannot be read gets one at the end instead, so the next dictation does not stick to this one.
public func textToPaste(_ text: String, after before: TextBeforeCursor) -> String {
    switch before {
    case .unknown: text + " "
    case .character(let character) where !character.isWhitespace: " " + text
    default: text
    }
}
