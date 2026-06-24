// The type/voice "Analyze" pipeline as an ordered fall-through chain. Each parser
// is tried in turn; the first that succeeds wins, and a throw means "I can't handle
// this — try the next." Wired (AppContainer) as:
//
//   1. DatabaseFoodParser   — direct USDA match (real numbers, the common case)
//   2. DecomposingFoodParser— FM itemizes a novel meal → grounds each part → sums
//   3. makeFoodParser()      — single-food FM/heuristic estimate (always succeeds)
//
// Stages 1–2 throw on no-match / FM-unavailable, so on a device without Apple
// Intelligence the chain is simply DB → single-food.

import Foundation
import NutritionCore

public struct CompositeFoodParser: FoodParsing {
    public enum CompositeError: Error, Sendable { case noParsers }

    private let parsers: [any FoodParsing]

    public init(_ parsers: [any FoodParsing]) {
        self.parsers = parsers
    }

    public func parse(text: String, units: UnitSystem) async throws -> ParsedFood {
        var lastError: Error?
        for parser in parsers {
            do { return try await parser.parse(text: text, units: units) }
            catch { lastError = error }
        }
        throw lastError ?? CompositeError.noParsers
    }
}
