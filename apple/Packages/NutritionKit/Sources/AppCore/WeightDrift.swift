// Decides when the user's weight has drifted enough from the weight their targets
// were computed with that we should suggest recalculating (the Today nudge).

import Foundation

public enum WeightDrift {
    /// Kilograms of change beyond which we nudge to update targets (~6–7 lb).
    public static let thresholdKg: Double = 3.0

    /// Signed change (latest − plan), or nil if either weight is unknown.
    public static func driftKg(plan: Double?, latest: Double?) -> Double? {
        guard let plan, let latest else { return nil }
        return latest - plan
    }

    /// Whether the drift is large enough to surface the nudge.
    public static func isSignificant(_ drift: Double?) -> Bool {
        guard let drift else { return false }
        return abs(drift) >= thresholdKg
    }
}
