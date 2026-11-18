import AppKit
import PapoRetoCore
import PapoRetoSherpa
import os

private let log = Logger(subsystem: "papo-reto", category: "model")

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var state = AppState()
    private var transcriber: Transcriber?
    private var fnMonitor: FnKeyMonitor?
    private let recorder = AudioRecorder()
    private var pendingSamples: [Float] = []
    private let unavailableItem = NSMenuItem(title: "Model not found. Run scripts/fetch-deps.sh model", action: nil, keyEquivalent: "")
    private let accessibilityItem = NSMenuItem(
        title: "Allow Accessibility in System Settings, then reopen Papo Reto", action: nil, keyEquivalent: "")

    func applicationDidFinishLaunching(_ notification: Notification) {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        let menu = NSMenu()
        menu.addItem(unavailableItem)
        menu.addItem(accessibilityItem)
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        item.menu = menu
        statusItem = item
        fnMonitor = FnKeyMonitor(
            onPress: { [weak self] in self?.handle(.fnPressed) },
            onRelease: { [weak self] held in self?.handle(.fnReleased(heldFor: held)) })
        accessibilityItem.isHidden = fnMonitor != nil
        render()
        loadModel()
    }

    private func loadModel() {
        Task.detached(priority: .userInitiated) {
            let start = ContinuousClock.now
            let transcriber = Transcriber()
            let elapsed = ContinuousClock.now - start
            // In the app, ~220 MB freed by the load stay counted in the footprint until malloc
            // gives them back (609-692 MB → 450 MB). Not in Transcriber: in the bench the same
            // call adds ~7 MB after transcribing (891.5 → 899 MB, limit 900).
            malloc_zone_pressure_relief(nil, 0)
            if transcriber == nil {
                log.error("model failed to load from \(Transcriber.defaultModelDir.path)")
            } else {
                log.info("model loaded in \(elapsed, privacy: .public)")
            }
            await self.modelDidLoad(transcriber)
        }
    }

    private func modelDidLoad(_ transcriber: Transcriber?) {
        self.transcriber = transcriber
        handle(transcriber == nil ? .modelFailed : .modelLoaded)
    }

    private func handle(_ event: AppEvent) {
        let (next, effects) = state.handling(event)
        state = next
        effects.forEach(perform)
        render()
    }

    private func perform(_ effect: AppEffect) {
        switch effect {
        case .startRecording: recorder.start()
        case .stopRecording: pendingSamples = recorder.stop()
        case .discardRecording: _ = recorder.stop(); pendingSamples = []
        case .transcribe: transcribe()
        }
    }

    /// The Core asks for `.transcribe` only with the model ready, one transcription at a time.
    private func transcribe() {
        guard let transcriber else { return }
        let samples = pendingSamples
        pendingSamples = []
        Task.detached(priority: .userInitiated) {
            let start = ContinuousClock.now
            let text = transcriber.transcribe(samples: samples, sampleRate: 16000)
            let seconds = Double(samples.count) / 16000
            log.info("transcribed \(seconds, format: .fixed(precision: 1), privacy: .public) s of audio in \(ContinuousClock.now - start, privacy: .public)")
            await self.didTranscribe(text)
        }
    }

    private func didTranscribe(_ transcription: String) {
        if let text = finalText(transcription) {
            let pasteboard = SystemPasteboard()
            let pending = paste(text, pasteboard: pasteboard, keyboard: SystemKeyboard())
            // Time for the focused app to read the text before the user's clipboard comes back.
            Task {
                try? await Task.sleep(for: .milliseconds(250))
                pending.restore(on: pasteboard)
            }
        }
        handle(.transcribed)
    }

    private func render() {
        let image = NSImage(systemSymbolName: state.iconName, accessibilityDescription: "Papo Reto")
        image?.isTemplate = true
        statusItem?.button?.image = image
        // An unknown symbol name yields nil: show text so the menu (and "Quit") stays reachable.
        statusItem?.button?.title = image == nil ? "PR" : ""
        unavailableItem.isHidden = state.model != .unavailable
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
// LSUIElement covers the bundle; this covers `swift run`, which has no Info.plist.
app.setActivationPolicy(.accessory)
app.run()
