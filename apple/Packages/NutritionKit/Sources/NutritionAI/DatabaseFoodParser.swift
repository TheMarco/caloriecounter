// FoodParsing over the on-device USDA database — the primary resolver for the
// type/voice "Analyze" action. A confident match returns real measured nutrition,
// a sensible portion, and (for dishes) an editable recipe breakdown; no match
// throws so a composite parser can fall through to Foundation Models.
//
// The entry keeps the user's WORDING ("a BLT made with white bread"), not the
// verbose USDA row name — the database supplies the numbers, not the label. (A
// suggestion the user explicitly taps keeps the canonical DB name instead.)

import Foundation
import NutritionCore

public enum DatabaseLookupError: Error, Sendable, Equatable {
    case noMatch
}

public struct DatabaseFoodParser: FoodParsing {
    private let database: FoodDatabase

    public init(database: FoodDatabase = .shared) {
        self.database = database
    }

    public func parse(text: String, units: UnitSystem) async throws -> ParsedFood {
        let query = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty, let resolved = database.resolve(query, units: units, keepingName: query) else {
            throw DatabaseLookupError.noMatch
        }
        return resolved
    }
}
