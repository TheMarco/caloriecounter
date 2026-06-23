// The shared output of every parser seam (text/voice/barcode/label/photo).
// Ported from `ParseFoodResponse.data` and `BarcodeResponse.data` in
// `src/types/index.ts`: the normalized food the user confirms before it becomes
// an `Entry`. All four AI/network flows converge on this type so `FoodConfirmView`
// (Phase 8) is parser-agnostic.

import Foundation

public struct ParsedFood: Codable, Sendable, Equatable, Hashable {
    public var food: String
    public var quantity: Double
    public var unit: String
    public var kcal: Double
    public var fat: Double       // grams
    public var carbs: Double     // grams
    public var protein: Double   // grams
    /// Optional 0…1 parser confidence.
    public var confidence: Double?
    /// Free-form parser notes (web `ParseFoodResponse.data.notes`).
    public var notes: String?
    // Optional context nutrients (nil = unknown).
    public var fiber: Double?      // grams
    public var sodium: Double?     // milligrams
    public var sugar: Double?      // grams
    public var nutritionConfidence: NutritionConfidence?

    public init(
        food: String,
        quantity: Double,
        unit: String,
        kcal: Double,
        fat: Double = 0,
        carbs: Double = 0,
        protein: Double = 0,
        confidence: Double? = nil,
        notes: String? = nil,
        fiber: Double? = nil,
        sodium: Double? = nil,
        sugar: Double? = nil,
        nutritionConfidence: NutritionConfidence? = nil
    ) {
        self.food = food
        self.quantity = quantity
        self.unit = unit
        self.kcal = kcal
        self.fat = fat
        self.carbs = carbs
        self.protein = protein
        self.confidence = confidence
        self.notes = notes
        self.fiber = fiber
        self.sodium = sodium
        self.sugar = sugar
        self.nutritionConfidence = nutritionConfidence
    }

    /// Build a parse from an existing entry (e.g. re-adding from autocomplete).
    public init(entry: Entry) {
        self.init(
            food: entry.food, quantity: entry.quantity, unit: entry.unit,
            kcal: entry.kcal, fat: entry.fat, carbs: entry.carbs, protein: entry.protein,
            confidence: entry.confidence, notes: nil,
            fiber: entry.fiber, sodium: entry.sodium, sugar: entry.sugar,
            nutritionConfidence: entry.nutritionConfidence
        )
    }

    /// Promote a confirmed parse into a persistable `Entry`.
    /// Caller supplies identity/day/instant/method; nutrition carries over 1:1.
    public func makeEntry(
        id: String,
        date: String,
        timestamp: Date,
        method: InputMethod
    ) -> Entry {
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
            method: method,
            confidence: confidence,
            fiber: fiber,
            sodium: sodium,
            sugar: sugar,
            nutritionConfidence: nutritionConfidence
        )
    }
}
