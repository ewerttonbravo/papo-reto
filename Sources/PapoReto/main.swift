import AppKit
import PapoRetoCore
import PapoRetoSherpa
import os

private let log = Logger(subsystem: "papo-reto", category: "model")

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var state = AppState.loading
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
        state = state.handling(transcriber == nil ? .modelFailed : .modelLoaded)
        render()
    }

    private func render() {
        let image = NSImage(systemSymbolName: state.iconName, accessibilityDescription: "Papo Reto")
        image?.isTemplate = true
        statusItem?.button?.image = image
        // An unknown symbol name yields nil: show text so the menu (and "Quit") stays reachable.
        statusItem?.button?.title = image == nil ? "PR" : ""
        unavailableItem.isHidden = state != .modelUnavailable
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
// LSUIElement covers the bundle; this covers `swift run`, which has no Info.plist.
app.setActivationPolicy(.accessory)
app.run()
