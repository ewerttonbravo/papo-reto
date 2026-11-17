import AppKit
import PapoRetoCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        let image = NSImage(systemSymbolName: AppState.loading.iconName, accessibilityDescription: "Papo Reto")
        image?.isTemplate = true
        item.button?.image = image
        // An unknown symbol name yields nil: show text so the menu (and "Sair") stays reachable.
        if image == nil { item.button?.title = "PR" }

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Sair", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        item.menu = menu
        statusItem = item
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
// LSUIElement covers the bundle; this covers `swift run`, which has no Info.plist.
app.setActivationPolicy(.accessory)
app.run()
