// Drives the text-entry flow: previous-food autocomplete from the store and
// on-device parsing via the FoodParsing seam (FM, or the heuristic fallback). In
// AppCore so the orchestration is unit-tested with a stub parser.

import Foundation
import Observation
import NutritionCore

@Observable
@MainActor
public final class TextInputModel {
    public var query: String = ""
    public private(set) var suggestions: [Entry] = []
    public private(set) var isParsing = false

    @ObservationIgnored private let store: any NutritionStoring
    @ObservationIgnored private let parser: any FoodParsing
    @ObservationIgnored private let units: UnitSystem

    public init(store: any NutritionStoring, parser: any FoodParsing, units: UnitSystem) {
        self.store = store
        self.parser = parser
        self.units = units
    }

    /// Refresh autocomplete from previously-eaten foods matching `query`.
    public func updateSuggestions() async {
        suggestions = (try? await store.searchPreviousFoods(query, limit: Constants.searchResultLimit)) ?? []
    }

    /// Parse the current query into a ParsedFood (throws on parser failure).
    public func parse() async throws -> ParsedFood {
        isParsing = true
        defer { isParsing = false }
        return try await parser.parse(text: query.trimmingCharacters(in: .whitespacesAndNewlines), units: units)
    }
}
