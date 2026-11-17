import CSherpaOnnx
import Foundation
import PapoRetoCore
import PapoRetoSherpa

/// Physical footprint (what Activity Monitor shows), its peak, and resident size, in MB.
func memory() -> (footprint: Double, peak: Double, resident: Double) {
    var info = task_vm_info_data_t()
    var count = mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<natural_t>.size)
    _ = withUnsafeMutablePointer(to: &info) {
        $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
            task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count)
        }
    }
    let mb = { (bytes: UInt64) in Double(bytes) / 1_048_576 }
    return (mb(info.phys_footprint), mb(UInt64(info.ledger_phys_footprint_peak)), mb(info.resident_size))
}

func seconds(since start: ContinuousClock.Instant) -> Double {
    let d = ContinuousClock.now - start
    return Double(d.components.seconds) + Double(d.components.attoseconds) / 1e18
}

let files = CommandLine.arguments.dropFirst()
guard !files.isEmpty else {
    print("usage: papo-reto-bench <wav>...")
    exit(2)
}

let loadStart = ContinuousClock.now
guard let transcriber = Transcriber() else {
    print("Could not load the model from \(Transcriber.defaultModelDir.path). Run scripts/fetch-deps.sh model.")
    exit(1)
}
let loadSeconds = seconds(since: loadStart)
let loaded = memory()
print(String(format: "load %.2f s · footprint %.0f MB · resident %.0f MB", loadSeconds, loaded.footprint, loaded.resident))

var latenciesPer10s: [Double] = []

for file in files {
    guard let wave = SherpaOnnxReadWave(file) else {
        print("\(file): not a readable WAV")
        exit(1)
    }
    defer { SherpaOnnxFreeWave(wave) }
    let w = wave.pointee
    let samples = Array(UnsafeBufferPointer(start: w.samples, count: Int(w.num_samples)))
    let audio = Double(w.num_samples) / Double(w.sample_rate)

    let start = ContinuousClock.now
    let text = transcriber.transcribe(samples: samples, sampleRate: w.sample_rate)
    let latency = seconds(since: start)
    latenciesPer10s.append(latency * 10 / audio)
    print(String(format: "%@ · audio %.1f s · %.2f s · %.2f s per 10 s", (file as NSString).lastPathComponent, audio, latency, latenciesPer10s.last!))
    print("  \(text)")
}
let end = memory()
print(String(format: "after transcribing: footprint %.0f MB · peak %.0f MB · resident %.0f MB", end.footprint, end.peak, end.resident))

let violations = BenchBudget.reference.violations(loadSeconds: loadSeconds, latenciesPer10s: latenciesPer10s, footprintMB: end.footprint)
guard violations.isEmpty else {
    violations.forEach { print("over budget: \($0)") }
    exit(1)
}
print("within budget")
