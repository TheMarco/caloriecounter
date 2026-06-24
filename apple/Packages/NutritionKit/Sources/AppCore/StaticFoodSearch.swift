// A FoodSearching stub that returns a fixed list regardless of query — used to
// wire the type-food flow in UI-test / demo mode (no network) and to drive
// TextInputModel unit tests deterministically. Defaults to "no matches".

import Foundation
import NutritionCore

public struct StaticFoodSearch: FoodSearching {
    private let results: [ParsedFood]
    /// Minimum query length before results are returned, mirroring the real
    /// resolver's 3-character floor so tests can exercise the threshold.
    private let minQueryLength: Int

    public init(results: [ParsedFood] = [], minQueryLength: Int = 3) {
        self.results = results
        self.minQueryLength = minQueryLength
    }

    public func search(_ query: String, units: UnitSystem) async throws -> [ParsedFood] {
        query.trimmingCharacters(in: .whitespacesAndNewlines).count >= minQueryLength ? results : []
    }
}
