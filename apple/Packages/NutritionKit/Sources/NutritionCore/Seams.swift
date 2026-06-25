// Protocol seams (architecture decision: features depend on these abstractions,
// never on SwiftData / the network directly). Each is pure Core — no framework
// leaks through — so the concrete implementations in NutritionStore / NutritionAPI
// are contained swaps, and tests can drive flows with mocks.
//
// Query/aggregation semantics mirror `src/utils/idb.ts`; the parser seams mirror
// the AI routing table (text/voice → FoodParsing, plate photo → PhotoParsing,
// barcode → BarcodeResolving).

import Foundation

/// Local-first persistence over the domain `Entry` plus per-day offsets.
/// All methods are async (the implementation is a SwiftData `@ModelActor`).
public protocol NutritionStoring: Sendable {
    /// Insert a new entry.
    func add(_ entry: Entry) async throws
    /// Update an existing entry in place (matched by `id`).
    func update(_ entry: Entry) async throws
    /// Delete an entry by id (no-op if absent).
    func delete(id: String) async throws

    /// Entries for a single local day, newest-first (web `getEntriesByDate`).
    func entries(on date: String) async throws -> [Entry]
    /// Entries within an inclusive `YYYY-MM-DD` range, newest-first
    /// (web `getEntriesInRange`; string comparison is valid for the key format).
    func entries(from startDate: String, to endDate: String) async throws -> [Entry]

    /// Summed macros for a day (web `getMacroTotalsForDate`).
    func macroTotals(on date: String) async throws -> MacroTotals
    /// Per-day totals + offsets for the last `days` days, oldest-first, for charts
    /// (web `getDailyMacroTotalsWithOffset`).
    func dailyTotals(lastDays days: Int) async throws -> [DayTotals]

    /// Previously-eaten foods matching `query`, ranked by frequency then recency,
    /// capped at `limit` (web `searchPreviousFood` over `getAllUniqueFood`).
    func searchPreviousFoods(_ query: String, limit: Int) async throws -> [Entry]

    /// The day's exercise/adjustment offset, 0 if unset (web `getCalorieOffset`).
    func offset(on date: String) async throws -> Double
    /// Upsert the day's offset (web `setCalorieOffset`).
    func setOffset(_ value: Double, on date: String) async throws

    /// Delete every entry and offset — a full data wipe for the "erase all data,
    /// start over" reset. Irreversible.
    func deleteAll() async throws

    // MARK: - Body weight (logged whenever; one measurement per local day)

    /// Upsert a weight measurement (matched by `id` = one per day).
    func addWeight(_ entry: WeightEntry) async throws
    /// Weight measurements within an inclusive `YYYY-MM-DD` range, oldest-first.
    func weights(from startDate: String, to endDate: String) async throws -> [WeightEntry]
    /// The most recent measurement, or nil if none logged.
    func latestWeight() async throws -> WeightEntry?
    /// Delete a measurement by id (no-op if absent).
    func deleteWeight(id: String) async throws
}

/// Text/voice → structured food (the OpenAI `/api/parse-food` proxy; a deterministic
/// heuristic stands in for UI-test/demo builds).
public protocol FoodParsing: Sendable {
    func parse(text: String, units: UnitSystem) async throws -> ParsedFood
}

/// Plate-of-food photo → structured food (cloud `/api/parse-photo` proxy).
public protocol PhotoParsing: Sendable {
    func parse(imageData: Data, units: UnitSystem, details: PhotoDetails) async throws -> ParsedFood
}

/// Barcode → structured food (OpenFoodFacts; when OFF knows the product but has no
/// nutriments, the name is estimated via the cloud food parser).
public protocol BarcodeResolving: Sendable {
    func resolve(code: String, units: UnitSystem) async throws -> ParsedFood
}
