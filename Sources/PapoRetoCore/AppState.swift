public enum AppEvent: Sendable, Equatable {
    case modelLoaded, modelFailed, fnPressed
    case fnReleased(heldFor: Duration)
    case transcribed(audio: Duration)
}

/// What the adapters must do after a transition.
public enum AppEffect: Sendable, Equatable {
    case startRecording, stopRecording, discardRecording, transcribe, reloadModel
}

public struct AppState: Sendable, Equatable {
    public enum Model: Sendable { case loading, ready, unavailable }
    public enum Activity: Sendable { case idle, recording, transcribing }

    /// Holding Fn longer than this is push-to-talk (ADR-005); shorter is a tap.
    public static let holdThreshold = Duration.milliseconds(300)
    /// Transcribing longer audio leaves the recognizer holding RAM it never gives back (T01: 60 s → 1.1 GB).
    public static let reloadAfter = Duration.seconds(30)

    public var model: Model
    public var activity: Activity

    public init(model: Model = .loading, activity: Activity = .idle) {
        self.model = model
        self.activity = activity
    }

    /// SF Symbol shown in the menu bar.
    public var iconName: String {
        switch (activity, model) {
        case (.recording, _): "mic.fill"
        case (.transcribing, _): "ellipsis.bubble"
        case (.idle, .loading): "hourglass"
        case (.idle, .ready): "mic"
        case (.idle, .unavailable): "exclamationmark.triangle"
        }
    }

    public func handling(_ event: AppEvent) -> (state: AppState, effects: [AppEffect]) {
        var next = self
        switch (event, model, activity) {
        case (.modelLoaded, .loading, _):
            next.model = .ready
            return (next, activity == .transcribing ? [.transcribe] : [])
        case (.modelFailed, .loading, _):
            next.model = .unavailable
            next.activity = .idle
            return (next, activity == .idle ? [] : [.discardRecording])
        case (.fnPressed, .loading, .idle), (.fnPressed, .ready, .idle):
            next.activity = .recording
            return (next, [.startRecording])
        case (.fnReleased(let held), _, .recording):
            guard held > Self.holdThreshold else {
                next.activity = .idle
                return (next, [.discardRecording])
            }
            next.activity = .transcribing
            return (next, model == .ready ? [.stopRecording, .transcribe] : [.stopRecording])
        case (.transcribed(let audio), _, .transcribing):
            next.activity = .idle
            guard audio > Self.reloadAfter else { return (next, []) }
            next.model = .loading
            return (next, [.reloadModel])
        default:
            return (self, [])
        }
    }
}
