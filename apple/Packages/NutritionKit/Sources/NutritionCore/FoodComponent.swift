// One ingredient line of a compound food's breakdown (e.g. the bacon in a BLT).
//
// Transient: components ride along on `ParsedFood` through the confirm/edit sheet
// so the user can see and adjust what went into a dish, but they are NOT persisted
// as structured data — on save an entry flattens to its top-line totals (plus an
// optional human-readable summary in `notes`). Sources: USDA/FNDDS recipes for a
// matched dish, or the on-device model's itemization of a described meal.

import Foundation

public struct FoodComponent: Codable, Sendable, Equatable, Hashable {
    public var name: String
    public var grams: Double
    public var kcal: Double
    public var fat: Double       // grams
    public var carbs: Double     // grams
    public var protein: Double   // grams
    public var fiber: Double?    // grams (nil = unknown)
    public var sodium: Double?   // milligrams
    public var sugar: Double?    // grams

    public init(
        name: String,
        grams: Double,
        kcal: Double,
        fat: Double = 0,
        carbs: Double = 0,
        protein: Double = 0,
        fiber: Double? = nil,
        sodium: Double? = nil,
        sugar: Double? = nil
    ) {
        self.name = name
        self.grams = grams
        self.kcal = kcal
        self.fat = fat
        self.carbs = carbs
        self.protein = protein
        self.fiber = fiber
        self.sodium = sodium
        self.sugar = sugar
    }

    /// Proportionally rescale every value to a new gram weight (used when the user
    /// changes one component's amount). A zero current weight scales to zero.
    public func scaled(toGrams newGrams: Double) -> FoodComponent {
        let r = grams > 0 ? newGrams / grams : 0
        return FoodComponent(
            name: name, grams: newGrams,
            kcal: kcal * r, fat: fat * r, carbs: carbs * r, protein: protein * r,
            fiber: fiber.map { $0 * r }, sodium: sodium.map { $0 * r }, sugar: sugar.map { $0 * r }
        )
    }
}

extension Array where Element == FoodComponent {
    /// Sum an optional nutrient across components: nil only when every component is
    /// nil (so "unknown" never silently becomes a fabricated 0).
    public func summed(_ keyPath: KeyPath<FoodComponent, Double?>) -> Double? {
        let known = compactMap { $0[keyPath: keyPath] }
        return known.isEmpty ? nil : known.reduce(0, +)
    }
}
