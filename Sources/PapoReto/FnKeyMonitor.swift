import AppKit

/// Fn press and release from a listen-only event tap on flagsChanged. Needs Accessibility.
@MainActor
final class FnKeyMonitor {
    private let onPress: () -> Void
    private let onRelease: (Duration) -> Void
    private var tap: CFMachPort?
    private var pressedAt: ContinuousClock.Instant?

    /// Nil without Accessibility; the system prompt asks for it once.
    init?(onPress: @escaping () -> Void, onRelease: @escaping (Duration) -> Void) {
        // The value of kAXTrustedCheckOptionPrompt, a global var that Swift 6 rejects as shared state.
        let prompt = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        guard AXIsProcessTrustedWithOptions(prompt) else { return nil }
        self.onPress = onPress
        self.onRelease = onRelease
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap, place: .headInsertEventTap, options: .listenOnly,
            eventsOfInterest: CGEventMask(1 << CGEventType.flagsChanged.rawValue),
            callback: { _, type, event, info in
                let fnDown = event.flags.contains(.maskSecondaryFn)
                let address = UInt(bitPattern: info)
                // The tap's run loop source is on the main run loop.
                MainActor.assumeIsolated {
                    let monitor = Unmanaged<FnKeyMonitor>.fromOpaque(UnsafeRawPointer(bitPattern: address)!)
                    monitor.takeUnretainedValue().handle(type, fnDown: fnDown)
                }
                return Unmanaged.passUnretained(event)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else { return nil }
        self.tap = tap
        CFRunLoopAddSource(CFRunLoopGetMain(), CFMachPortCreateRunLoopSource(nil, tap, 0), .commonModes)
    }

    private func handle(_ type: CGEventType, fnDown: Bool) {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            return
        }
        switch (fnDown, pressedAt) {
        case (true, nil):
            pressedAt = .now
            onPress()
        case (false, let start?):
            pressedAt = nil
            onRelease(.now - start)
        default:
            break
        }
    }
}
