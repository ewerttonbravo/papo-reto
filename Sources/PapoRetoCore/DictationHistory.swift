/// The latest dictations, newest first. Memory only (ADR-034): quitting the app clears it.
public struct DictationHistory {
    public private(set) var entries: [String] = []

    public init() {}

    public mutating func add(_ text: String) {
        entries.insert(text, at: 0)
    }
}
