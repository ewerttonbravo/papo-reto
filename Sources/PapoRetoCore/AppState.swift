public enum AppEvent: Sendable {
    case modelLoaded, modelFailed
}

public enum AppState: CaseIterable, Sendable {
    case loading, ready, recording, transcribing, modelUnavailable

    /// SF Symbol shown in the menu bar.
    public var iconName: String {
        switch self {
        case .loading: "hourglass"
        case .ready: "mic"
        case .recording: "mic.fill"
        case .transcribing: "ellipsis.bubble"
        case .modelUnavailable: "exclamationmark.triangle"
        }
    }

    public func handling(_ event: AppEvent) -> AppState {
        switch event {
        case .modelLoaded: .ready
        case .modelFailed: .modelUnavailable
        }
    }
}
