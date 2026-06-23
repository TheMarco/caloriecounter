// SwiftData persistent models for the local-only store (plan Phase 2).
//
// `EntryRecord` is a flat, fully-queryable row — every field the app filters or
// sorts on (`date`, `timestamp`, `food`) is a scalar column, so predicates run
// in the store rather than in memory. `method` is persisted as the
// `InputMethod.rawValue` string (web-faithful: "barcode"/"voice"/"text"/"photo")
// and mapped back through the enum on read.
//
// `DayOffsetRecord` is the Swift home of the web `offset:{YYYY-MM-DD}` key — one
// row per local day holding that day's exercise/adjustment calorie offset.
//
// Both use `@Attribute(.unique)` on their natural key so an insert of an existing
// key upserts instead of duplicating.

import Foundation
import SwiftData
import NutritionCore

@Model
public final class EntryRecord {
    @Attribute(.unique) public var id: String
    public var date: String          // YYYY-MM-DD (local calendar day)
    public var timestamp: Date
    public var food: String
    public var quantity: Double
    public var unit: String
    public var kcal: Double
    public var fat: Double
    public var carbs: Double
    public var protein: Double
    public var method: String        // InputMethod.rawValue
    public var confidence: Double?
    public var fiber: Double?         // grams (nil = unknown)
    public var sodium: Double?        // milligrams (nil = unknown)
    public var sugar: Double?         // grams (nil = unknown)
    public var nutritionConfidence: String?   // NutritionConfidence.rawValue

    public init(from e: Entry) {
        self.id = e.id
        self.date = e.date
        self.timestamp = e.timestamp
        self.food = e.food
        self.quantity = e.quantity
        self.unit = e.unit
        self.kcal = e.kcal
        self.fat = e.fat
        self.carbs = e.carbs
        self.protein = e.protein
        self.method = e.method.rawValue
        self.confidence = e.confidence
        self.fiber = e.fiber
        self.sodium = e.sodium
        self.sugar = e.sugar
        self.nutritionConfidence = e.nutritionConfidence?.rawValue
    }

    /// Overwrite this row in place from a domain entry (id is the match key and
    /// is left untouched).
    public func update(from e: Entry) {
        date = e.date
        timestamp = e.timestamp
        food = e.food
        quantity = e.quantity
        unit = e.unit
        kcal = e.kcal
        fat = e.fat
        carbs = e.carbs
        protein = e.protein
        method = e.method.rawValue
        confidence = e.confidence
        fiber = e.fiber
        sodium = e.sodium
        sugar = e.sugar
        nutritionConfidence = e.nutritionConfidence?.rawValue
    }

    /// Map back to the domain `Entry`. An unrecognized `method` string falls back
    /// to `.text` (the web's default input method) rather than dropping the row.
    public func toDomain() -> Entry {
        Entry(
            id: id,
            date: date,
            timestamp: timestamp,
            food: food,
            quantity: quantity,
            unit: unit,
            kcal: kcal,
            fat: fat,
            carbs: carbs,
            protein: protein,
            method: InputMethod(rawValue: method) ?? .text,
            confidence: confidence,
            fiber: fiber,
            sodium: sodium,
            sugar: sugar,
            nutritionConfidence: nutritionConfidence.flatMap(NutritionConfidence.init(rawValue:))
        )
    }
}

@Model
public final class DayOffsetRecord {
    @Attribute(.unique) public var date: String   // YYYY-MM-DD
    public var offset: Double

    public init(date: String, offset: Double) {
        self.date = date
        self.offset = offset
    }
}

/// A body-weight measurement (one per local day; canonical kilograms).
@Model
public final class WeightRecord {
    @Attribute(.unique) public var id: String     // weight-<YYYY-MM-DD>
    public var date: String                        // YYYY-MM-DD
    public var timestamp: Date
    public var weightKg: Double

    public init(from w: WeightEntry) {
        self.id = w.id
        self.date = w.date
        self.timestamp = w.timestamp
        self.weightKg = w.weightKg
    }

    public func update(from w: WeightEntry) {
        date = w.date
        timestamp = w.timestamp
        weightKg = w.weightKg
    }

    public func toDomain() -> WeightEntry {
        WeightEntry(id: id, date: date, timestamp: timestamp, weightKg: weightKg)
    }
}
