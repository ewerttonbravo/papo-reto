import AppKit
import os

private let log = Logger(subsystem: "papo-reto", category: "fn")

/// Fn press and release, Esc and Fn+key from a listen-only event tap. Needs Accessibility.
/// It sees every keystroke: only the Esc key code and the Fn state are read, nothing is logged.
@MainActor
final class FnKeyMonitor {
    private let onPress: (Duration?) -> Void
    private let onRelease: (Duration) -> Void
    private let onCancel: () -> Void
    private var tap: CFMachPort?
    /// Event times in nanoseconds of uptime.
    private var pressedAt: UInt64?
    private var releasedAt: UInt64?

    /// Nil without Accessibility; the system prompt asks for it once.
    init?(onPress: @escaping (Duration?) -> Void, onRelease: @escaping (Duration) -> Void, onCancel: @escaping () -> Void) {
        // The value of kAXTrustedCheckOptionPrompt, a global var that Swift 6 rejects as shared state.
        let prompt = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        guard AXIsProcessTrustedWithOptions(prompt) else { return nil }
        self.onPress = onPress
        self.onRelease = onRelease
        self.onCancel = onCancel
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap, place: .headInsertEventTap, options: .listenOnly,
            eventsOfInterest: CGEventMask(1 << CGEventType.flagsChanged.rawValue | 1 << CGEventType.keyDown.rawValue),
            callback: { _, type, event, info in
                let fnDown = event.flags.contains(.maskSecondaryFn)
                let isEscape = type == .keyDown && event.getIntegerValueField(.keyboardEventKeycode) == 53
                // When the key moved, not when this runs: a cold microphone start blocks the main
                // thread ~300 ms and a quick tap queued behind it would read as a hold.
                let time = type == .flagsChanged ? event.timestamp : clock_gettime_nsec_np(CLOCK_UPTIME_RAW)
                let address = UInt(bitPattern: info)
                // The tap's run loop source is on the main run loop.
                MainActor.assumeIsolated {
                    let monitor = Unmanaged<FnKeyMonitor>.fromOpaque(UnsafeRawPointer(bitPattern: address)!)
                    monitor.takeUnretainedValue().handle(type, fnDown: fnDown, isEscape: isEscape, at: time)
                }
                return Unmanaged.passUnretained(event)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            log.error("event tap not created although Accessibility is granted")
            return nil
        }
        self.tap = tap
        CFRunLoopAddSource(CFRunLoopGetMain(), CFMachPortCreateRunLoopSource(nil, tap, 0), .commonModes)
    }

    private func handle(_ type: CGEventType, fnDown: Bool, isEscape: Bool, at time: UInt64) {
        if type == .keyDown {
            // Arrows and F-keys carry the Fn flag without Fn held, so "held" is this monitor's own state.
            if isEscape || pressedAt != nil { onCancel() }
            return
        }
        var fnDown = fnDown
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            // Fn may have changed while the tap was off; a lost release would keep the microphone on.
            fnDown = CGEventSource.flagsState(.combinedSessionState).contains(.maskSecondaryFn)
        }
        switch (fnDown, pressedAt) {
        case (true, nil):
            pressedAt = time
            onPress(releasedAt.map { .nanoseconds(Int64(time) - Int64($0)) })
        case (false, let start?):
            pressedAt = nil
            releasedAt = time
            onRelease(.nanoseconds(Int64(time) - Int64(start)))
        default:
            break
        }
    }
}
