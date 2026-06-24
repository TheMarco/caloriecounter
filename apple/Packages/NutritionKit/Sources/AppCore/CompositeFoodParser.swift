// The type/voice "Analyze" pipeline: try the on-device USDA database first (real
// measured numbers for foods/dishes that exist in it — the common case), and only
// fall back to Foundation Models (or the heuristic) for the genuine long tail it
// can't match. The DB resolver throws on no-match, which is the fall-through signal.
//
// Mirrors CompositeBarcodeResolver: a primary resolver with a graceful fallback.

import Foundation
import NutritionCore

public struct CompositeFoodParser: FoodParsing {
    private let database: any FoodParsing
    private let fallback: any FoodParsing

    public init(database: any FoodParsing, fallback: any FoodParsing) {
        self.database = database
        self.fallback = fallback
    }

    public func parse(text: String, units: UnitSystem) async throws -> ParsedFood {
        if let resolved = try? await database.parse(text: text, units: units) {
            return resolved
        }
        return try await fallback.parse(text: text, units: units)
    }
}
