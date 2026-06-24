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
    /// Optional ingredient breakdown for compound foods (a matched dish's recipe
    /// or the model's itemization). Transient — flattened to totals on save.
    public var components: [FoodComponent]?

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
        nutritionConfidence: NutritionConfidence? = nil,
        components: [FoodComponent]? = nil
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
        self.components = components
    }

    /// A copy whose top-line macros equal the sum of its components (used after a
    /// component is edited/removed). Unknown context nutrients stay unknown unless
    /// at least one component reports them. No-op when there are no components.
    public func totaledFromComponents() -> ParsedFood {
        guard let components, !components.isEmpty else { return self }
        var copy = self
        copy.kcal = components.reduce(0) { $0 + $1.kcal }
        copy.fat = components.reduce(0) { $0 + $1.fat }
        copy.carbs = components.reduce(0) { $0 + $1.carbs }
        copy.protein = components.reduce(0) { $0 + $1.protein }
        copy.fiber = components.summed(\.fiber)
        copy.sodium = components.summed(\.sodium)
        copy.sugar = components.summed(\.sugar)
        return copy
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
