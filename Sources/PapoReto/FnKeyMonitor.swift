import AppKit
import Carbon.HIToolbox
import os

private let log = Logger(subsystem: "papo-reto", category: "fn")

/// Fn press and release and every key down, from a listen-only event tap. Needs Accessibility.
/// It sees every keystroke: only whether it is Esc goes out, nothing is logged.
@MainActor
final class FnKeyMonitor {
    private enum Input { case key(isEscape: Bool), fn(down: Bool, at: TimeInterval), tapDisabled }
    /// NX_SYSDEFINED with subtype NX_SUBTYPE_AUX_CONTROL_BUTTONS: what F1-F12 send as media keys
    /// when "Use F1, F2, etc. keys as standard function keys" is on, so Fn+F1 does not arrive as keyDown.
    private static let systemDefined: UInt32 = 14
    private static let mediaKeySubtype: Int16 = 8

    private let onPress: (Duration?) -> Void
    private let onRelease: (Duration) -> Void
    private let onKey: (_ isEscape: Bool) -> Void
    private var tap: CFMachPort?
    /// Event times in seconds of uptime.
    private var pressedAt: TimeInterval?
    private var releasedAt: TimeInterval?

    /// Nil without Accessibility. Never prompts: it is retried each time the permission may have changed.
    init?(onPress: @escaping (Duration?) -> Void, onRelease: @escaping (Duration) -> Void,
          onKey: @escaping (_ isEscape: Bool) -> Void) {
        guard AXIsProcessTrusted() else { return nil }
        self.onPress = onPress
        self.onRelease = onRelease
        self.onKey = onKey
        let mask = 1 << CGEventType.flagsChanged.rawValue | 1 << CGEventType.keyDown.rawValue | 1 << Self.systemDefined
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap, place: .headInsertEventTap, options: .listenOnly,
            eventsOfInterest: CGEventMask(mask),
            callback: { _, type, event, info in
                let input: Input
                switch type {
                case .keyDown:
                    input = .key(isEscape: event.getIntegerValueField(.keyboardEventKeycode) == kVK_Escape)
                case .flagsChanged:
                    // When the key moved, not when this runs: a cold microphone start blocks the main
                    // thread ~300 ms and a quick tap queued behind it would read as a hold. NSEvent gives
                    // seconds on every architecture; the raw CGEvent timestamp unit differs on Apple Silicon.
                    let time = NSEvent(cgEvent: event)?.timestamp ?? ProcessInfo.processInfo.systemUptime
                    input = .fn(down: event.flags.contains(.maskSecondaryFn), at: time)
                case .tapDisabledByTimeout, .tapDisabledByUserInput:
                    input = .tapDisabled
                default:
                    guard type.rawValue == FnKeyMonitor.systemDefined,
                          NSEvent(cgEvent: event)?.subtype.rawValue == FnKeyMonitor.mediaKeySubtype
                    else { return Unmanaged.passUnretained(event) }
                    input = .key(isEscape: false)
                }
                let address = UInt(bitPattern: info)
                // The tap's run loop source is on the main run loop.
                MainActor.assumeIsolated {
                    let monitor = Unmanaged<FnKeyMonitor>.fromOpaque(UnsafeRawPointer(bitPattern: address)!)
                    monitor.takeUnretainedValue().handle(input)
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

    private func handle(_ input: Input) {
        switch input {
        case .key(let isEscape):
            onKey(isEscape)
        case .fn(let down, let time):
            fnChanged(down: down, at: time)
        case .tapDisabled:
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            // Fn may have changed while the tap was off; a lost release would keep the microphone on.
            let down = CGEventSource.flagsState(.combinedSessionState).contains(.maskSecondaryFn)
            fnChanged(down: down, at: ProcessInfo.processInfo.systemUptime)
        }
    }

    private func fnChanged(down: Bool, at time: TimeInterval) {
        switch (down, pressedAt) {
        case (true, nil):
            pressedAt = time
            onPress(releasedAt.map { .seconds(time - $0) })
        case (false, let start?):
            pressedAt = nil
            releasedAt = time
            onRelease(.seconds(time - start))
        default:
            break
        }
    }
}
