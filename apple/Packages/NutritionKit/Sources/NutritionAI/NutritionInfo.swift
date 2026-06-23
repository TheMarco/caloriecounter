// The guided-generation type for on-device food parsing (Foundation Models).
// `@Generable` makes the model emit exactly these fields; `@Guide` ranges keep
// macro values sane. Mirrors `ParseFoodResponse.data` so it maps 1:1 to the
// shared `ParsedFood`.
//
// An explicit memberwise init is declared so the type is constructible in tests
// and previews regardless of the macro-synthesized initializers.

import Foundation
import FoundationModels
import NutritionCore

@Generable(description: "Nutritional breakdown for a described food item, for one realistic serving")
public struct NutritionInfo: Sendable {
    @Guide(description: "Standardized food name, no brand")
    public var food: String
    @Guide(description: "Quantity for the serving")
    public var quantity: Double
    @Guide(description: "Unit: g, ml, cup, tbsp, tsp, piece, slice, bowl, plate, serving, oz, lb")
    public var unit: String
    @Guide(description: "Total calories for this serving", .range(0...5000))
    public var kcal: Double
    @Guide(description: "Total fat grams", .range(0...500))
    public var fat: Double
    @Guide(description: "Total carb grams", .range(0...500))
    public var carbs: Double
    @Guide(description: "Total protein grams", .range(0...500))
    public var protein: Double

    public init(food: String, quantity: Double, unit: String,
                kcal: Double, fat: Double, carbs: Double, protein: Double) {
        self.food = food
        self.quantity = quantity
        self.unit = unit
        self.kcal = kcal
        self.fat = fat
        self.carbs = carbs
        self.protein = protein
    }

    /// Promote the model's structured output into the shared parser type.
    public func toParsedFood() -> ParsedFood {
        ParsedFood(food: food, quantity: quantity, unit: unit,
                   kcal: kcal, fat: fat, carbs: carbs, protein: protein)
    }
}
