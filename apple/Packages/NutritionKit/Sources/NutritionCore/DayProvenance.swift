// DayProvenance — where a day's logged numbers came from, so History can show
// provenance honestly (a measured day reads differently from a day of estimates)
// without ever implying one is "better" than another. Pure + unit-tested.

import Foundation

public enum DayProvenance: Sendable, Equatable {
    case none        // no entries logged
    case allExact    // every entry is measured (label/barcode) or your own correction
    case mixed       // a blend of measured and estimated
    case estimated   // every entry is an estimate (or unknown)

    /// Classify from each entry's source. Exactness follows
    /// `NutritionConfidence.isExact` (nil → not exact).
    public static func from(confidences: [NutritionConfidence?]) -> DayProvenance {
        guard !confidences.isEmpty else { return .none }
        let exact = confidences.map { $0?.isExact ?? false }
        if exact.allSatisfy({ $0 }) { return .allExact }
        if exact.allSatisfy({ !$0 }) { return .estimated }
        return .mixed
    }
}
