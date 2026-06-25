// HonestNumber — the app's honesty-first calorie formatter.
//
// Exact sources (nutrition label, barcode database, a user's own correction) get
// their precise number. Estimates are rounded to a deliberately coarse grid and
// prefixed with "about", so an AI guess never wears the costume of a measured
// value. Pure and deterministic so it lives in NutritionCore and is unit-tested.

import Foundation

public enum HonestNumber {

    /// A calorie string honest about its provenance.
    /// - exact: `"520 kcal"` — the precise rounded integer.
    /// - estimate: `"about 520 kcal"` — rounded to the nearest 10 (≥100) or 5 (<100).
    /// - zero: always `"0 kcal"` with no "about" (an estimate of nothing isn't a guess).
    public static func kcal(_ value: Double, exact: Bool) -> String {
        let n = exact ? Int(value.rounded()) : estimateRounded(value)
        if exact || n == 0 {
            return "\(n) kcal"
        }
        return "about \(n) kcal"
    }

    /// The coarse rounding used for estimates, exposed so callers that lay out the
    /// big number separately from its "about" prefix share one source of truth.
    /// Nearest 10 at/above 100, nearest 5 below — keeps small snacks from snapping
    /// to a misleadingly round number.
    public static func estimateRounded(_ value: Double) -> Int {
        let step: Double = value >= 100 ? 10 : 5
        return Int((value / step).rounded()) * Int(step)
    }
}
