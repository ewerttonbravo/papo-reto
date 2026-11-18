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
    private let unavailableItem = NSMenuItem(title: "Model not found. Run scripts/fetch-deps.sh model", action: nil, keyEquivalent: "")

    func applicationDidFinishLaunching(_ notification: Notification) {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        let menu = NSMenu()
        menu.addItem(unavailableItem)
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        item.menu = menu
        statusItem = item
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
        state = state.handling(transcriber == nil ? .modelFailed : .modelLoaded).state
        render()
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
