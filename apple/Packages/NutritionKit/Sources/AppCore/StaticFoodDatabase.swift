// A FoodDatabaseQuerying stub returning a fixed list regardless of query — used to
// drive TextInputModel unit tests deterministically without loading the real DB.

import Foundation
import NutritionCore

public struct StaticFoodDatabase: FoodDatabaseQuerying {
    private let results: [ParsedFood]
    /// Minimum query length before results are returned (mirrors the real DB floor).
    private let minQueryLength: Int

    public init(results: [ParsedFood] = [], minQueryLength: Int = 3) {
        self.results = results
        self.minQueryLength = minQueryLength
    }

    public func suggestions(_ query: String, units: UnitSystem, limit: Int) -> [ParsedFood] {
        guard query.trimmingCharacters(in: .whitespacesAndNewlines).count >= minQueryLength else { return [] }
        return Array(results.prefix(limit))
    }
}
