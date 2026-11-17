import Testing
import PapoRetoCore

private let budget = BenchBudget.reference

@Test func justUnderEveryLimitIsWithinBudget() {
    #expect(budget.violations(loadSeconds: 4.99, latenciesPer10s: [0.9, 1.49], footprintMB: 899.9).isEmpty)
}

@Test func loadOf5sBreaksTheBudget() {
    let violations = budget.violations(loadSeconds: 5, latenciesPer10s: [1.49], footprintMB: 899.9)
    #expect(violations.count == 1)
    #expect(violations.first?.contains("load 5.00 s") == true)
}

@Test func oneFileAt1_5sPer10sBreaksTheBudget() {
    let violations = budget.violations(loadSeconds: 4.99, latenciesPer10s: [1.5, 0.9], footprintMB: 899.9)
    #expect(violations.count == 1)
    #expect(violations.first?.contains("latency 1.50 s per 10 s") == true)
}

@Test func footprintOf900MBBreaksTheBudget() {
    let violations = budget.violations(loadSeconds: 4.99, latenciesPer10s: [1.49], footprintMB: 900)
    #expect(violations.count == 1)
    #expect(violations.first?.contains("footprint 900 MB") == true)
}

@Test func everyMetricOverReportsThreeViolations() {
    #expect(budget.violations(loadSeconds: 5, latenciesPer10s: [1.5], footprintMB: 900).count == 3)
}
