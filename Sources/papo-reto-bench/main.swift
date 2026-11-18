import CSherpaOnnx
import Foundation
import PapoRetoCore
import PapoRetoSherpa

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
let loaded = processMemory()
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
    guard audio > 0 else {
        print("\(file): empty WAV")
        exit(1)
    }

    let start = ContinuousClock.now
    let text = transcriber.transcribe(samples: samples, sampleRate: w.sample_rate)
    let latency = seconds(since: start)
    let per10s = latency * 10 / audio
    latenciesPer10s.append(per10s)
    print(String(format: "%@ · audio %.1f s · %.2f s · %.2f s per 10 s", (file as NSString).lastPathComponent, audio, latency, per10s))
    print("  \(text)")
}
let end = processMemory()
print(String(format: "after transcribing: footprint %.1f MB · peak %.0f MB · resident %.0f MB", end.footprint, end.peak, end.resident))

let violations = BenchBudget.reference.violations(loadSeconds: loadSeconds, latenciesPer10s: latenciesPer10s, footprintMB: end.footprint)
guard violations.isEmpty else {
    violations.forEach { print("over budget: \($0)") }
    exit(3)  // make bench tells a budget miss (3) from a setup error (1, 2)
}
print("within budget")
