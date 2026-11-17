import Foundation

/// The performance budget `make bench` enforces on the reference Mac (see CLAUDE.md).
public struct BenchBudget: Sendable {
    public let maxLoadSeconds: Double
    public let maxLatencyPer10s: Double
    public let maxFootprintMB: Double

    public static let reference = BenchBudget(maxLoadSeconds: 5, maxLatencyPer10s: 1.5, maxFootprintMB: 900)

    /// One line per metric at or over its limit; empty means within budget.
    public func violations(loadSeconds: Double, latenciesPer10s: [Double], footprintMB: Double) -> [String] {
        var found: [String] = []
        if loadSeconds >= maxLoadSeconds {
            found.append(String(format: "load %.2f s (limit < %g s)", loadSeconds, maxLoadSeconds))
        }
        if let worst = latenciesPer10s.max(), worst >= maxLatencyPer10s {
            found.append(String(format: "latency %.2f s per 10 s in the slowest file (limit < %g s)", worst, maxLatencyPer10s))
        }
        if footprintMB >= maxFootprintMB {
            found.append(String(format: "footprint %.1f MB after transcribing (limit < %g MB)", footprintMB, maxFootprintMB))
        }
        return found
    }
}
