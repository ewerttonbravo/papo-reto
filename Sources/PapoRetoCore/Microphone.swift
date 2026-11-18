/// UID to record from; nil means the system default. A saved device that is gone stays saved,
/// so it is used again as soon as it reconnects.
public func microphoneInUse(saved: String?, connected: [String]) -> String? {
    guard let saved, connected.contains(saved) else { return nil }
    return saved
}
