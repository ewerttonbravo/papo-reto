public enum AppState: CaseIterable, Sendable {
    case loading, ready, recording, transcribing

    public var iconName: String { "" }
}
