// Drives the text-entry flow: previous-food autocomplete from the store, branded
// product matches from the FoodSearching seam (OpenFoodFacts), and on-device
// parsing via the FoodParsing seam (FM, or the heuristic fallback). In AppCore so
// the orchestration is unit-tested with stub seams.

import Foundation
import Observation
import NutritionCore

@Observable
@MainActor
public final class TextInputModel {
    public var query: String = ""
    public private(set) var suggestions: [Entry] = []
    /// Branded matches from OpenFoodFacts for the current query — tappable suggestions
    /// that carry exact label data. Empty for generic/short/offline queries.
    public private(set) var productMatches: [ParsedFood] = []
    /// Generic-food matches from the on-device USDA database (dishes + ingredients),
    /// resolved to portioned ParsedFoods with breakdowns. Local; empty for short queries.
    public private(set) var dbMatches: [ParsedFood] = []
    public private(set) var isParsing = false
    public private(set) var isSearching = false

    @ObservationIgnored private let store: any NutritionStoring
    @ObservationIgnored private let parser: any FoodParsing
    @ObservationIgnored private let foodSearch: any FoodSearching
    @ObservationIgnored private let foodDatabase: any FoodDatabaseQuerying
    @ObservationIgnored private let units: UnitSystem

    /// Pause after the last keystroke before hitting the network, in nanoseconds.
    @ObservationIgnored private let searchDebounce: UInt64

    public init(store: any NutritionStoring,
                parser: any FoodParsing,
                foodSearch: any FoodSearching,
                foodDatabase: any FoodDatabaseQuerying,
                units: UnitSystem,
                searchDebounceMilliseconds: UInt64 = 350) {
        self.store = store
        self.parser = parser
        self.foodSearch = foodSearch
        self.foodDatabase = foodDatabase
        self.units = units
        self.searchDebounce = searchDebounceMilliseconds * 1_000_000
    }

    /// Refresh local autocomplete from previously-eaten foods matching `query`.
    public func updateSuggestions() async {
        suggestions = (try? await store.searchPreviousFoods(query, limit: Constants.searchResultLimit)) ?? []
    }

    /// Refresh on-device USDA database matches. Local + fast, but the ~13k-food scan
    /// is offloaded so typing stays smooth; a stale result (query moved on) is dropped.
    public func searchDatabase() async {
        let snapshot = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard snapshot.count >= 3 else { dbMatches = []; return }
        let db = foodDatabase
        let units = self.units
        let matches = await Task.detached { db.suggestions(snapshot, units: units, limit: 5) }.value
        guard snapshot == query.trimmingCharacters(in: .whitespacesAndNewlines) else { return }
        dbMatches = matches
    }

    /// Debounced online product search. Captures the query, waits out the debounce,
    /// and bails if the query changed meanwhile (a newer keystroke supersedes it) so
    /// only the settled query hits the network. A throw/offline result clears matches.
    public func searchProducts() async {
        let snapshot = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard snapshot.count >= 3 else { productMatches = []; isSearching = false; return }

        isSearching = true
        try? await Task.sleep(nanoseconds: searchDebounce)
        // Superseded by a newer keystroke — let that task own the result.
        guard snapshot == query.trimmingCharacters(in: .whitespacesAndNewlines) else { return }

        let matches = (try? await foodSearch.search(snapshot, units: units)) ?? []
        // Re-check: the query may have changed during the network round-trip.
        guard snapshot == query.trimmingCharacters(in: .whitespacesAndNewlines) else { return }
        productMatches = matches
        isSearching = false
    }

    /// Parse the current query into a ParsedFood (throws on parser failure).
    public func parse() async throws -> ParsedFood {
        isParsing = true
        defer { isParsing = false }
        return try await parser.parse(text: query.trimmingCharacters(in: .whitespacesAndNewlines), units: units)
    }
}
