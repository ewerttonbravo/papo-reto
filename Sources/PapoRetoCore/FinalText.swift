import Foundation

/// The text that goes to the user; nil means there is nothing to deliver.
public func finalText(_ transcription: String) -> String? {
    let text = transcription.trimmingCharacters(in: .whitespacesAndNewlines)
    return text.isEmpty ? nil : text
}
