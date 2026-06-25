// HonestNumber: the honesty-first calorie formatter. Exact sources read as a
// precise number; estimates are rounded and prefixed with "about" so the UI
// never presents an AI guess as if it were a label value.

import Testing
@testable import NutritionCore

@Suite("HonestNumber")
struct HonestNumberTests {

    @Test("exact values render the precise number, no 'about'")
    func exactIsPrecise() {
        #expect(HonestNumber.kcal(520, exact: true) == "520 kcal")
        #expect(HonestNumber.kcal(518, exact: true) == "518 kcal")
        #expect(HonestNumber.kcal(92, exact: true) == "92 kcal")
    }

    @Test("estimates ≥100 round to the nearest 10 and gain 'about'")
    func estimateRoundsToTen() {
        #expect(HonestNumber.kcal(518, exact: false) == "about 520 kcal")
        #expect(HonestNumber.kcal(523, exact: false) == "about 520 kcal")
        #expect(HonestNumber.kcal(525, exact: false) == "about 530 kcal")  // .5 rounds up
        #expect(HonestNumber.kcal(104, exact: false) == "about 100 kcal")
    }

    @Test("estimates <100 round to the nearest 5")
    func estimateRoundsToFiveBelowHundred() {
        #expect(HonestNumber.kcal(92, exact: false) == "about 90 kcal")
        #expect(HonestNumber.kcal(93, exact: false) == "about 95 kcal")
        #expect(HonestNumber.kcal(7, exact: false) == "about 5 kcal")
    }

    @Test("zero is always '0 kcal' with no 'about', regardless of exactness")
    func zeroIsClean() {
        #expect(HonestNumber.kcal(0, exact: true) == "0 kcal")
        #expect(HonestNumber.kcal(0, exact: false) == "0 kcal")
        #expect(HonestNumber.kcal(2, exact: false) == "0 kcal")  // rounds to 0 → no "about"
    }

    @Test("estimateRounded exposes the same rounding for layout reuse")
    func estimateRoundedHelper() {
        #expect(HonestNumber.estimateRounded(518) == 520)
        #expect(HonestNumber.estimateRounded(92) == 90)
        #expect(HonestNumber.estimateRounded(0) == 0)
    }
}
