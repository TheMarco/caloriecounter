import Testing
@testable import AppCore

@Suite("WeightDrift")
struct WeightDriftTests {

    @Test("drift is the signed change, significant only past ~3 kg either way")
    func threshold() {
        #expect(WeightDrift.driftKg(plan: 80, latest: 76) == -4)
        #expect(WeightDrift.driftKg(plan: 80, latest: 84) == 4)
        #expect(WeightDrift.isSignificant(-4))
        #expect(WeightDrift.isSignificant(3))
        #expect(!WeightDrift.isSignificant(2.5))
        #expect(!WeightDrift.isSignificant(nil))
        #expect(WeightDrift.driftKg(plan: nil, latest: 80) == nil)
        #expect(WeightDrift.driftKg(plan: 80, latest: nil) == nil)
    }
}
