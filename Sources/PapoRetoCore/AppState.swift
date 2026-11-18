public enum AppEvent: Sendable, Equatable {
    /// Any key down. Recording means Fn is held, so any key cancels; hands-free only Esc (ADR-005).
    case keyPressed(isEscape: Bool)
    case modelLoaded, modelFailed, recordingLimitReached
    /// A model file is absent or fails its SHA-256: the adapter downloads it, then loads.
    case downloadStarted
    /// The menu's Retry after a failed download or load.
    case retryRequested
    /// nil on the first press since launch.
    case fnPressed(sinceRelease: Duration?)
    case fnReleased(heldFor: Duration)
    case transcribed(footprintMB: Double)
}

/// What the adapters must do after a transition.
public enum AppEffect: Sendable, Equatable {
    case startRecording, stopRecording, discardRecording, transcribe, reloadModel, alertRecordingLimit
    /// Check every file's SHA-256, download what fails, then load.
    case prepareModel
}

public struct AppState: Sendable, Equatable {
    public enum Model: Sendable { case loading, downloading, ready, unavailable }
    public enum Activity: Sendable { case idle, recording, handsFree, transcribing }

    /// Holding Fn longer than this is push-to-talk (ADR-005); shorter is a tap.
    public static let holdThreshold = Duration.milliseconds(300)
    /// A press this soon after a tap's release is a double tap: hands-free (ADR-005).
    public static let doubleTapWindow = Duration.milliseconds(400)
    /// The recognizer keeps the RAM of the longest audio it saw (app: 28.5 s → 1,005 MB); at the budget it is recreated.
    public static let reloadAtFootprintMB = BenchBudget.reference.maxFootprintMB
    /// A recording stops by itself here and is transcribed whole, which bounds the RAM peak.
    public static let recordingLimit = Duration.seconds(120)

    public var model: Model
    public var activity: Activity
    /// The last Fn release was a tap; the next press consumes it.
    public var afterTap: Bool

    public init(model: Model = .loading, activity: Activity = .idle, afterTap: Bool = false) {
        self.model = model
        self.activity = activity
        self.afterTap = afterTap
    }

    /// SF Symbol shown in the menu bar.
    public var iconName: String {
        switch (activity, model) {
        case (.recording, _), (.handsFree, _): "mic.fill"
        case (.transcribing, _): "ellipsis.bubble"
        case (.idle, .loading): "hourglass"
        case (.idle, .downloading): "arrow.down.circle"
        case (.idle, .ready): "mic"
        case (.idle, .unavailable): "exclamationmark.triangle"
        }
    }

    public func handling(_ event: AppEvent) -> (state: AppState, effects: [AppEffect]) {
        var next = self
        switch (event, model, activity) {
        case (.modelLoaded, .loading, _), (.modelLoaded, .downloading, _):
            next.model = .ready
            return (next, activity == .transcribing ? [.transcribe] : [])
        case (.modelFailed, .loading, _), (.modelFailed, .downloading, _):
            return droppingAudio(model: .unavailable)
        case (.downloadStarted, .loading, _):
            return droppingAudio(model: .downloading)
        case (.retryRequested, .unavailable, _):
            return (AppState(), [.prepareModel])
        case (.fnPressed(let sinceRelease), .loading, .idle), (.fnPressed(let sinceRelease), .ready, .idle):
            let doubleTap = afterTap && sinceRelease.map { $0 < Self.doubleTapWindow } == true
            next.activity = doubleTap ? .handsFree : .recording
            next.afterTap = false
            return (next, [.startRecording])
        case (.fnReleased(let held), _, .recording):
            guard held > Self.holdThreshold else {
                next.activity = .idle
                next.afterTap = true
                return (next, [.discardRecording])
            }
            return stoppingToTranscribe(alertingLimit: false)
        case (.fnPressed, _, .handsFree):
            return stoppingToTranscribe(alertingLimit: false)
        // A tap then a hold to talk: the hold's release ends it like push-to-talk.
        case (.fnReleased(let held), _, .handsFree) where held > Self.holdThreshold:
            return stoppingToTranscribe(alertingLimit: false)
        case (.keyPressed, _, .recording), (.keyPressed(isEscape: true), _, .handsFree):
            next.activity = .idle
            return (next, [.discardRecording])
        case (.recordingLimitReached, _, .recording), (.recordingLimitReached, _, .handsFree):
            return stoppingToTranscribe(alertingLimit: true)
        case (.transcribed(let footprintMB), _, .transcribing):
            next.activity = .idle
            guard footprintMB >= Self.reloadAtFootprintMB else { return (next, []) }
            next.model = .loading
            return (next, [.reloadModel])
        default:
            return (self, [])
        }
    }

    /// Audio waiting for this model would wait forever (or for minutes): drop it.
    private func droppingAudio(model: Model) -> (state: AppState, effects: [AppEffect]) {
        (AppState(model: model), activity == .idle ? [] : [.discardRecording])
    }

    /// Without the model the audio waits; `.modelLoaded` transcribes it.
    private func stoppingToTranscribe(alertingLimit: Bool) -> (state: AppState, effects: [AppEffect]) {
        var next = self
        next.activity = .transcribing
        return (next, [.stopRecording] + (alertingLimit ? [.alertRecordingLimit] : []) + (model == .ready ? [.transcribe] : []))
    }
}
