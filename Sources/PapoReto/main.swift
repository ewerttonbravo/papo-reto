import AppKit
import PapoRetoCore
import PapoRetoSherpa
import os

private let log = Logger(subsystem: "papo-reto", category: "model")
private let accessibilityLog = Logger(subsystem: "papo-reto", category: "accessibility")

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private static let microphoneKey = "microphoneUID"
    private var statusItem: NSStatusItem?
    private var state = AppState()
    private var transcriber: Transcriber?
    private var fnMonitor: FnKeyMonitor?
    private let recorder = AudioRecorder()
    private var pendingSamples: [Float] = []
    /// Sends fnHeldPastThreshold, then recordingLimitReached; cancelled when the recording ends.
    private var recordingTimer: Task<Void, Never>?
    /// Download progress, or Retry after a failure.
    private let modelItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    private let microphoneMenu = NSMenu()
    private var history = DictationHistory()
    private let historyMenu = NSMenu()
    /// Without a submenu (and no action) the menu greys it out: nothing dictated yet.
    private let historyItem = NSMenuItem(title: "Recent", action: nil, keyEquivalent: "")
    private let accessibilityItem = NSMenuItem(
        title: "Allow Accessibility…", action: #selector(openAccessibilitySettings), keyEquivalent: "")
    private var accessibilityObserver: NSObjectProtocol?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        let menu = NSMenu()
        modelItem.target = self
        accessibilityItem.target = self
        menu.delegate = self
        menu.addItem(modelItem)
        menu.addItem(accessibilityItem)
        historyMenu.delegate = self
        menu.addItem(historyItem)
        let microphoneItem = NSMenuItem(title: "Microphone", action: nil, keyEquivalent: "")
        microphoneMenu.delegate = self
        microphoneItem.submenu = microphoneMenu
        menu.addItem(microphoneItem)
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        item.menu = menu
        statusItem = item
        if !AXIsProcessTrusted() { askForAccessibility() }
        startFnMonitor()
        if Self.detectorModel == nil { log.error("no speech detector bundled: silence goes to the model") }
        render()
        prepareModel(hashing: false)
    }

    /// A record from another signature (an ad-hoc update) stays on in the list while tccd denies it
    /// without asking: reset ours, then prompt. Denying is asked again at the next launch.
    private func askForAccessibility() {
        let id = Bundle.main.bundleIdentifier
        // Off the main thread: a slow tccd must not hold the menu bar icon and the model load.
        Task.detached(priority: .userInitiated) {
            if let id {
                let reset = Process()
                reset.executableURL = URL(fileURLWithPath: "/usr/bin/tccutil")
                reset.arguments = ["reset", "Accessibility", id]
                do {
                    try reset.run()
                    reset.waitUntilExit()
                    accessibilityLog.info("record reset, status \(reset.terminationStatus, privacy: .public)")
                } catch {
                    accessibilityLog.error("tccutil did not run: \(String(describing: type(of: error)), privacy: .public)")
                }
            }
            // The value of kAXTrustedCheckOptionPrompt, a global var that Swift 6 rejects as shared state.
            await MainActor.run { _ = AXIsProcessTrustedWithOptions(["AXTrustedCheckOptionPrompt": true] as CFDictionary) }
        }
    }

    /// Retried when the Accessibility list changes and when the menu opens, so granting needs no reopening.
    private func startFnMonitor() {
        guard fnMonitor == nil else { return }
        fnMonitor = FnKeyMonitor(
            onPress: { [weak self] since in self?.handle(.fnPressed(sinceRelease: since)) },
            onRelease: { [weak self] held in self?.handle(.fnReleased(heldFor: held)) },
            onKey: { [weak self] isEscape in self?.handle(.keyPressed(isEscape: isEscape)) })
        accessibilityItem.isHidden = fnMonitor != nil
        if fnMonitor != nil {
            accessibilityObserver.map(DistributedNotificationCenter.default().removeObserver)
            accessibilityObserver = nil
        } else if accessibilityObserver == nil {
            // Undocumented, posted on any change to the list: no polling while the permission is missing.
            accessibilityObserver = DistributedNotificationCenter.default().addObserver(
                forName: Notification.Name("com.apple.accessibility.api"), object: nil, queue: .main
            ) { _ in
                MainActor.assumeIsolated {
                    accessibilityLog.info("list changed, trusted: \(AXIsProcessTrusted(), privacy: .public)")
                    self.startFnMonitor()
                }
                // Posted ~5 ms before tccd records the grant, and only once (macOS 26): look again later.
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    MainActor.assumeIsolated { self.startFnMonitor() }
                }
            }
        }
    }

    @objc private func openAccessibilitySettings() {
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
    }

    /// Checks every file (by size; by SHA-256 when `hashing`), downloads the ones that fail, then loads.
    private func prepareModel(hashing: Bool) {
        Task.detached(priority: .userInitiated) {
            let dir = Transcriber.defaultModelDir
            let checkStart = ContinuousClock.now
            let invalid = hashing ? ModelStore.invalidFiles(in: dir) : ModelStore.missingFiles(in: dir)
            log.info("model checked in \(ContinuousClock.now - checkStart, privacy: .public), \(invalid.count, privacy: .public) files to download")
            if !invalid.isEmpty {
                await self.handle(.downloadStarted)
                let downloadStart = ContinuousClock.now
                do {
                    try await ModelStore.download(invalid, to: dir) { status in
                        // FIFO, unlike one Task per update: the percent never goes backwards.
                        DispatchQueue.main.async { MainActor.assumeIsolated { self.showDownload(status) } }
                    }
                    log.info("model downloaded in \(ContinuousClock.now - downloadStart, privacy: .public)")
                } catch {
                    // The domain and code, not the description, which can carry the user's path.
                    let code = (error as NSError).code, domain = (error as NSError).domain
                    log.error("model download failed: \(String(describing: type(of: error)), privacy: .public) \(domain, privacy: .public) \(code, privacy: .public)")
                    await self.modelDidLoad(nil)
                    return
                }
            }
            let start = ContinuousClock.now
            let transcriber = Transcriber(modelDir: dir)
            let elapsed = ContinuousClock.now - start
            // In the app, ~220 MB freed by the load stay counted in the footprint until malloc
            // gives them back (609-692 MB → 450 MB). Not in Transcriber: in the bench the same
            // call adds ~7 MB after transcribing (891.5 → 899 MB, limit 900).
            malloc_zone_pressure_relief(nil, 0)
            if transcriber == nil {
                log.error("model failed to load")
            } else {
                log.info("model loaded in \(elapsed, privacy: .public)")
            }
            await self.modelDidLoad(transcriber)
        }
    }

    /// A late status from a download that already ended must not cover Retry.
    private func showDownload(_ status: String) {
        if state.model == .downloading { modelItem.title = status }
    }

    @objc private func retry() { handle(.retryRequested) }

    private func modelDidLoad(_ transcriber: Transcriber?) {
        self.transcriber = transcriber
        handle(transcriber == nil ? .modelFailed : .modelLoaded)
    }

    private func handle(_ event: AppEvent) {
        let (next, effects) = state.handling(event)
        // Every keystroke lands here; most change nothing.
        guard next != state || !effects.isEmpty else { return }
        state = next
        effects.forEach(perform)
        render()
    }

    private func perform(_ effect: AppEffect) {
        switch effect {
        case .startRecording:
            // Detached and before the microphone: the sleep runs while a cold start blocks the main thread ~300 ms.
            recordingTimer = Task.detached { [weak self] in
                try? await Task.sleep(for: AppState.holdThreshold)
                await self?.recordingTimerFired(.fnHeldPastThreshold)
                try? await Task.sleep(for: AppState.recordingLimit - AppState.holdThreshold)
                await self?.recordingTimerFired(.recordingLimitReached)
            }
            // Nothing saved means the default: skip asking Core Audio on every Fn press.
            recorder.start(from: savedMicrophone == nil ? nil : currentMicrophone(among: AudioDevices.inputs()))
        case .stopRecording: recordingTimer?.cancel(); pendingSamples = recorder.stop()
        case .discardRecording: recordingTimer?.cancel(); _ = recorder.stop(); pendingSamples = []
        case .transcribe: transcribe()
        case .reloadModel:
            log.info("reloading the model to give its RAM back")
            // Destroy before loading: both recognizers at once would peak at ~2.4 GB.
            transcriber = nil
            prepareModel(hashing: false)
        // Retry hashes: a same-size corrupt file passes the size check and would fail again.
        case .prepareModel: prepareModel(hashing: true)
        // Bottle: the microphone records it, and in the T13 spike it was the only one that kept the first word.
        case .playStartSound: play("Bottle")
        // The microphone is already off: any sound will do.
        case .playStopSound: play("Pop")
        }
    }

    private func recordingTimerFired(_ event: AppEvent) {
        // A cancel can land after the sleep ends; without this, a stale timer acts on the next recording.
        guard !Task.isCancelled else { return }
        if event == .recordingLimitReached { log.info("recording limit reached") }
        // A tap's release can still be queued behind a busy main thread: ask the keyboard itself.
        if event == .fnHeldPastThreshold,
           !CGEventSource.flagsState(.combinedSessionState).contains(.maskSecondaryFn) { return }
        handle(event)
    }

    /// From the start even when still playing: play() on a playing NSSound does nothing.
    private func play(_ systemSound: String) {
        guard let sound = NSSound(named: systemSound) else { return }
        sound.stop()
        sound.play()
    }

    /// The Core asks for `.transcribe` only with the model ready, one transcription at a time.
    private func transcribe() {
        guard let transcriber else { return }
        let samples = pendingSamples
        pendingSamples = []
        let work = Task.detached(priority: .userInitiated) {
            let seconds = Double(samples.count) / 16000
            let check = ContinuousClock.now
            let verdict = AppState.audioVerdict(sampleCount: samples.count, sampleRate: 16000,
                                                containsSpeech: Self.detectorModel.map { model in { Self.containsSpeech(samples, model: model) } })
            // An empty text pastes nothing and still ends in `.transcribed`, back to idle.
            guard verdict == .transcribe else {
                log.info("skipped \(seconds, format: .fixed(precision: 2), privacy: .public) s of audio: \(String(describing: verdict), privacy: .public), checked in \(ContinuousClock.now - check, privacy: .public)")
                return ("", processMemory().footprint)
            }
            let start = ContinuousClock.now
            let text = transcriber.transcribe(samples: samples, sampleRate: 16000)
            let footprint = processMemory().footprint
            log.info("transcribed \(seconds, format: .fixed(precision: 1), privacy: .public) s of audio in \(ContinuousClock.now - start, privacy: .public), footprint \(footprint, format: .fixed(precision: 0), privacy: .public) MB")
            return (text, footprint)
        }
        // Only the finished detached task held the recognizer, so a reload frees it before loading the new one.
        Task {
            let (text, footprint) = await work.value
            didTranscribe(text, footprintMB: footprint)
        }
    }

    /// Bundled by `make app` (ADR-020); nil under `swift run`, which then transcribes everything.
    private nonisolated static let detectorModel = Bundle.main.url(forResource: "silero_vad", withExtension: "onnx")

    /// Created per dictation and freed on return: no RAM at rest (ADR-020). A detector that fails says speech.
    private nonisolated static func containsSpeech(_ samples: [Float], model: URL) -> Bool {
        let start = ContinuousClock.now
        guard let detector = SpeechDetector(model: model) else {
            log.error("speech detector failed to load, transcribing anyway")
            return true
        }
        let found = detector.containsSpeech(samples)
        if found { log.info("speech found in \(ContinuousClock.now - start, privacy: .public)") }
        return found
    }

    private func didTranscribe(_ transcription: String, footprintMB: Double) {
        if let text = finalText(transcription) {
            history.add(text)
            historyItem.submenu = historyMenu
            let pasteboard = SystemPasteboard()
            let pending = paste(text, pasteboard: pasteboard, keyboard: SystemKeyboard())
            // Time for the focused app to read the text before the user's clipboard comes back.
            Task {
                try? await Task.sleep(for: .milliseconds(250))
                pending.restore(on: pasteboard)
            }
        }
        handle(.transcribed(footprintMB: footprintMB))
    }

    private var savedMicrophone: String? { UserDefaults.standard.string(forKey: Self.microphoneKey) }

    /// The saved microphone while it is connected; nil records from the system default.
    private func currentMicrophone(among devices: [InputDevice]) -> InputDevice? {
        let uid = microphoneInUse(saved: savedMicrophone, connected: devices.map(\.uid))
        return devices.first { $0.uid == uid }
    }

    /// The main menu: a fallback should the Accessibility notification not arrive.
    func menuWillOpen(_ menu: NSMenu) {
        if menu === statusItem?.menu { startFnMonitor() }
    }

    /// Rebuilt on each opening, so a device plugged in meanwhile shows up without polling.
    func menuNeedsUpdate(_ menu: NSMenu) {
        if menu === historyMenu { return showHistory() }
        guard menu === microphoneMenu else { return }
        let devices = AudioDevices.inputs()
        let inUse = currentMicrophone(among: devices)?.uid
        menu.removeAllItems()
        let entries: [(title: String, uid: String?)] = [("System Default", nil)] + devices.map { ($0.name, $0.uid) }
        for entry in entries {
            let item = NSMenuItem(title: entry.title, action: #selector(chooseMicrophone(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = entry.uid
            item.state = entry.uid == inUse ? .on : .off
            menu.addItem(item)
        }
    }

    private func showHistory() {
        historyMenu.removeAllItems()
        for text in history.entries {
            let item = NSMenuItem(title: historyTitle(text), action: #selector(copyDictation(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = text
            historyMenu.addItem(item)
        }
    }

    /// A plain copy, unlike the paste: the user asked for it, so clipboard managers may keep it.
    @objc private func copyDictation(_ sender: NSMenuItem) {
        guard let text = sender.representedObject as? String else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    @objc private func chooseMicrophone(_ sender: NSMenuItem) {
        UserDefaults.standard.set(sender.representedObject as? String, forKey: Self.microphoneKey)
    }

    private static func image(for icon: AppState.MenuIcon) -> NSImage? {
        let symbol: String
        switch icon {
        case .ready: return ProfileGlyph.menuBarImage(.none)
        case .listening: return ProfileGlyph.menuBarImage(.waves)
        case .thinking: return ProfileGlyph.menuBarImage(.dots)
        case .loading: symbol = "hourglass"
        case .downloading: symbol = "arrow.down.circle"
        case .unavailable: symbol = "exclamationmark.triangle"
        }
        let image = NSImage(systemSymbolName: symbol, accessibilityDescription: "Papo Reto")
        image?.isTemplate = true
        return image
    }

    private func render() {
        let image = Self.image(for: state.icon)
        statusItem?.button?.image = image
        // An unknown symbol name yields nil: show text so the menu (and "Quit") stays reachable.
        statusItem?.button?.title = image == nil ? "PR" : ""
        modelItem.isHidden = state.model != .unavailable && state.model != .downloading
        let failed = state.model == .unavailable
        modelItem.action = failed ? #selector(retry) : nil
        if failed { modelItem.title = "Model unavailable. Retry" }
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
// LSUIElement covers the bundle; this covers `swift run`, which has no Info.plist.
app.setActivationPolicy(.accessory)
app.run()
