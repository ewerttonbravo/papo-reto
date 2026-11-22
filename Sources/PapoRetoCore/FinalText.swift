import Foundation

/// The text that goes to the user; nil means there is nothing to deliver.
public func finalText(_ transcription: String) -> String? {
    let text = transcription.trimmingCharacters(in: .whitespacesAndNewlines)
    return text.isEmpty ? nil : text
}

/// What goes to the cursor: one trailing space keeps the next dictation from sticking to this one.
public func textToPaste(_ text: String) -> String {
    text + " "
}

/// What precedes the cursor in the focused field; unknown when the field does not answer.
public enum TextBeforeCursor: Sendable {
    case unknown
    case nothing
    case character(Character)
}

public func textToPaste(_ text: String, after before: TextBeforeCursor) -> String {
    " " + text
}
