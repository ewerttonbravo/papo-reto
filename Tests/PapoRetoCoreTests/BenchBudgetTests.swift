import Testing
import PapoRetoCore

private let budget = BenchBudget.reference

@Test func loadUnder5sIsWithinBudget() {
    #expect(budget.violations(loadSeconds: 4.99, latenciesPer10s: [1.49], footprintMB: 899.9).isEmpty)
}

@Test func loadOf5sBreaksTheBudget() {
    let violations = budget.violations(loadSeconds: 5, latenciesPer10s: [1.49], footprintMB: 899.9)
    #expect(violations.count == 1)
    #expect(violations.first?.contains("load 5.00 s") == true)
}
