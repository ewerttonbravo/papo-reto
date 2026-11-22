/// The latest dictations, newest first. Memory only (ADR-034): quitting the app clears it.
public struct DictationHistory {
    public static let limit = 10
    public private(set) var entries: [String] = []

    public init() {}

    public mutating func add(_ text: String) {
        entries.insert(text, at: 0)
        if entries.count > Self.limit { entries.removeLast() }
    }
}

/// The dictation's title in the Recent menu, short enough to keep the menu narrow.
public func historyTitle(_ text: String) -> String {
    text.count > 50 ? text.prefix(50) + "…" : text
}
