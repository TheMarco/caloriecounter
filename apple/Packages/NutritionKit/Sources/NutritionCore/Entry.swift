// The core food entry — the Swift port of `Entry` in `src/types/index.ts`.
//
// Field renames from the web shape (the iOS store is a fresh local store, not a
// byte-faithful round-trip of the IndexedDB JSON, so the cleaner Swift names are
// used per the plan's domain-mapping table):
//   web `dt`  (YYYY-MM-DD local string) → `date`
//   web `ts`  (Unix-ms number)          → `timestamp: Date`
//   web `qty`                           → `quantity`
// `id` stays a `String` (web used cuid2; new entries use `UUID().uuidString`) so
// any imported web data still round-trips by id.

import Foundation

public struct Entry: Identifiable, Codable, Sendable, Equatable {
    /// Stable identity (cuid2 on the web; `UUID().uuidString` for new iOS entries).
    public let id: String
    /// Local calendar day this entry belongs to, `YYYY-MM-DD` (see `LocalDate`).
    public var date: String
    /// Creation instant; replaces the web's `ts` Unix-ms number. Used for ordering.
    public var timestamp: Date
    public var food: String
    public var quantity: Double
    public var unit: String
    public var kcal: Double
    public var fat: Double       // grams
    public var carbs: Double     // grams
    public var protein: Double   // grams
    public var method: InputMethod
    /// Optional 0…1 parser confidence (web `Entry.confidence?`).
    public var confidence: Double?

    public init(
        id: String,
        date: String,
        timestamp: Date,
        food: String,
        quantity: Double,
        unit: String,
        kcal: Double,
        fat: Double,
        carbs: Double,
        protein: Double,
        method: InputMethod,
        confidence: Double? = nil
    ) {
        self.id = id
        self.date = date
        self.timestamp = timestamp
        self.food = food
        self.quantity = quantity
        self.unit = unit
        self.kcal = kcal
        self.fat = fat
        self.carbs = carbs
        self.protein = protein
        self.method = method
        self.confidence = confidence
    }
}
