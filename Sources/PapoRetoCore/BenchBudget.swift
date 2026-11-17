import Foundation

/// The performance budget `make bench` enforces on the reference Mac (see CLAUDE.md).
public struct BenchBudget: Sendable {
    public let maxLoadSeconds: Double

    public static let reference = BenchBudget(maxLoadSeconds: 5)

    /// One line per metric at or over its limit; empty means within budget.
    public func violations(loadSeconds: Double, latenciesPer10s: [Double], footprintMB: Double) -> [String] {
        var found: [String] = []
        if loadSeconds >= maxLoadSeconds {
            found.append(String(format: "load %.2f s (limit < %.0f s)", loadSeconds, maxLoadSeconds))
        }
        return found
    }
}
