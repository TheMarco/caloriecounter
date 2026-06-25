// SwiftData row for a per-food correction (the app's memory of *your* numbers).
//
// Additive to the schema — a new, independent table keyed by the normalized
// food+unit `key`. Adding it is a lightweight migration: existing entries/weights/
// offsets are untouched, and a store opened before this type existed simply gains
// an empty CorrectionRecord table. `@Attribute(.unique)` on `key` makes an insert
// of an existing key upsert instead of duplicating.

import Foundation
import SwiftData
import NutritionCore

@Model
public final class CorrectionRecord {
    @Attribute(.unique) public var key: String
    public var kcal: Double
    public var fat: Double
    public var carbs: Double
    public var protein: Double
    public var fiber: Double?
    public var sodium: Double?
    public var sugar: Double?
    public var updatedAt: Date

    public init(from c: FoodCorrection) {
        self.key = c.key
        self.kcal = c.kcal; self.fat = c.fat; self.carbs = c.carbs; self.protein = c.protein
        self.fiber = c.fiber; self.sodium = c.sodium; self.sugar = c.sugar
        self.updatedAt = c.updatedAt
    }

    /// Overwrite this row in place (the `key` is the match and is left untouched).
    public func update(from c: FoodCorrection) {
        kcal = c.kcal; fat = c.fat; carbs = c.carbs; protein = c.protein
        fiber = c.fiber; sodium = c.sodium; sugar = c.sugar
        updatedAt = c.updatedAt
    }

    public func toDomain() -> FoodCorrection {
        FoodCorrection(key: key, kcal: kcal, fat: fat, carbs: carbs, protein: protein,
                       fiber: fiber, sodium: sodium, sugar: sugar, updatedAt: updatedAt)
    }
}
