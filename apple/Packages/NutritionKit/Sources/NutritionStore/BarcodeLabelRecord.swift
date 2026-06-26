// SwiftData row for a user-verified nutrition label, keyed by barcode (the app's
// memory of *your* confirmed numbers for a packaged product).
//
// Additive to the schema — a new, independent table. Adding it is a lightweight
// migration: existing tables are untouched, and a store opened before this type
// existed simply gains an empty BarcodeLabelRecord table. `@Attribute(.unique)` on
// `barcode` makes an insert of an existing barcode upsert instead of duplicating.

import Foundation
import SwiftData
import NutritionCore

@Model
public final class BarcodeLabelRecord {
    @Attribute(.unique) public var barcode: String
    public var name: String
    public var servingDescription: String
    public var kcal: Double
    public var protein: Double
    public var carbs: Double
    public var fat: Double
    public var updatedAt: Date

    public init(from label: VerifiedLabel) {
        self.barcode = label.barcode
        self.name = label.name
        self.servingDescription = label.facts.servingDescription
        self.kcal = label.facts.kcal
        self.protein = label.facts.protein
        self.carbs = label.facts.carbs
        self.fat = label.facts.fat
        self.updatedAt = label.updatedAt
    }

    /// Overwrite this row in place (the `barcode` is the match and is left untouched).
    public func update(from label: VerifiedLabel) {
        name = label.name
        servingDescription = label.facts.servingDescription
        kcal = label.facts.kcal
        protein = label.facts.protein
        carbs = label.facts.carbs
        fat = label.facts.fat
        updatedAt = label.updatedAt
    }

    public func toDomain() -> VerifiedLabel {
        VerifiedLabel(
            barcode: barcode,
            name: name,
            facts: LabelFacts(servingDescription: servingDescription, kcal: kcal,
                              protein: protein, carbs: carbs, fat: fat),
            updatedAt: updatedAt
        )
    }
}
