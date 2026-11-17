public enum AppEvent: Sendable {
    case modelLoaded
}

public enum AppState: CaseIterable, Sendable {
    case loading, ready, recording, transcribing

    /// SF Symbol shown in the menu bar.
    public var iconName: String {
        switch self {
        case .loading: "hourglass"
        case .ready: "mic"
        case .recording: "mic.fill"
        case .transcribing: "ellipsis.bubble"
        }
    }

    public func handling(_ event: AppEvent) -> AppState {
        .ready
    }
}
