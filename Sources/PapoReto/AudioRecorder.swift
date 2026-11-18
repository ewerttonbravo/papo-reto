import AVFoundation
import os

private let log = Logger(subsystem: "papo-reto", category: "audio")

/// The chosen microphone (or the system default) as 16 kHz mono Float32, in memory. The engine runs only while recording.
/// `@unchecked Sendable`: the tap runs on an audio thread and only touches `samples` under the lock.
final class AudioRecorder: @unchecked Sendable {
    private let format = AVAudioFormat(
        commonFormat: .pcmFormatFloat32, sampleRate: 16000, channels: 1, interleaved: false)!
    private var engine: AVAudioEngine?
    private let lock = NSLock()
    private var samples: [Float] = []

    /// `nil` records from the system default.
    func start(from device: InputDevice?) {
        // A new engine per recording follows the current device and its format;
        // a reused one can keep a stale format after a device change and crash in installTap.
        let engine = AVAudioEngine()
        let input = engine.inputNode
        // The device must be set before reading the format, which comes from it.
        var chosen = device
        if let device, !select(device, on: input) {
            log.error("could not select \(device.name, privacy: .private(mask: .hash)), recording from the system default")
            chosen = nil
        }
        let inputFormat = input.outputFormat(forBus: 0)
        guard let converter = AVAudioConverter(from: inputFormat, to: format) else {
            log.error("no converter from the input format \(inputFormat, privacy: .public)")
            return
        }
        lock.withLock { samples = [] }
        input.installTap(onBus: 0, bufferSize: 4096, format: inputFormat) { [self] buffer, _ in
            append(converting: buffer, with: converter)
        }
        do {
            try engine.start()
            self.engine = engine
            // Device names often carry the owner's name: hashed, still telling devices apart.
            if let chosen {
                log.info("recording from \(chosen.name, privacy: .private(mask: .hash))")
            } else {
                log.info("recording from the system default")
            }
        } catch {
            input.removeTap(onBus: 0)
            log.error("microphone did not start: \(error, privacy: .public)")
        }
    }

    /// Stops the engine and hands over what was recorded.
    func stop() -> [Float] {
        engine?.inputNode.removeTap(onBus: 0)
        engine?.stop()
        engine = nil
        return lock.withLock {
            defer { samples = [] }
            return samples
        }
    }

    private func select(_ device: InputDevice, on input: AVAudioInputNode) -> Bool {
        guard let unit = input.audioUnit else { return false }
        var id = device.id
        return AudioUnitSetProperty(
            unit, kAudioOutputUnitProperty_CurrentDevice, kAudioUnitScope_Global, 0,
            &id, UInt32(MemoryLayout<AudioDeviceID>.size)) == noErr
    }

    private func append(converting buffer: AVAudioPCMBuffer, with converter: AVAudioConverter) {
        let capacity = AVAudioFrameCount(Double(buffer.frameLength) * format.sampleRate / buffer.format.sampleRate) + 1
        guard let output = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: capacity) else { return }
        // convert(to:) calls the block synchronously on this thread, so these never race.
        nonisolated(unsafe) var fed = false
        nonisolated(unsafe) let input = buffer
        converter.convert(to: output, error: nil) { _, status in
            status.pointee = fed ? .noDataNow : .haveData
            defer { fed = true }
            return fed ? nil : input
        }
        guard let channel = output.floatChannelData?[0] else { return }
        let converted = UnsafeBufferPointer(start: channel, count: Int(output.frameLength))
        lock.withLock { samples.append(contentsOf: converted) }
    }
}
