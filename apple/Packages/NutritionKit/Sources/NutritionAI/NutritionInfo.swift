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
    @Guide(description: "The single most natural unit. Use 'piece' for whole handheld foods (sandwich, burger, hot dog, taco, wrap, egg, muffin). Use 'slice' ONLY for foods actually served in slices (pizza, bread, cake). Use 'bowl' or 'plate' for served meals, and 'g'/'ml' for loose ingredients. One of: g, ml, cup, tbsp, tsp, piece, slice, bowl, plate, serving, oz, lb")
    public var unit: String
    @Guide(description: "Total calories for this serving", .range(0...5000))
    public var kcal: Double
    @Guide(description: "Total fat grams", .range(0...500))
    public var fat: Double
    @Guide(description: "Total carb grams", .range(0...500))
    public var carbs: Double
    @Guide(description: "Total protein grams", .range(0...500))
    public var protein: Double
    @Guide(description: "Dietary fiber grams for this serving — your best estimate", .range(0...100))
    public var fiber: Double
    @Guide(description: "Sodium milligrams for this serving — your best estimate", .range(0...10000))
    public var sodium: Double
    @Guide(description: "Total sugars grams for this serving — your best estimate", .range(0...500))
    public var sugar: Double

    public init(food: String, quantity: Double, unit: String,
                kcal: Double, fat: Double, carbs: Double, protein: Double,
                fiber: Double = 0, sodium: Double = 0, sugar: Double = 0) {
        self.food = food
        self.quantity = quantity
        self.unit = unit
        self.kcal = kcal
        self.fat = fat
        self.carbs = carbs
        self.protein = protein
        self.fiber = fiber
        self.sodium = sodium
        self.sugar = sugar
    }

    /// Promote the model's structured output into the shared parser type, fixing
    /// awkward units for whole handheld foods (e.g. a sandwich tagged "slice").
    /// Fiber/sodium are rounded so AI estimates don't look falsely precise.
    public func toParsedFood() -> ParsedFood {
        let naturalUnit = FoodUnitNormalizer.normalizedUnit(food: food, unit: unit, quantity: quantity)
        return ParsedFood(food: food, quantity: quantity, unit: naturalUnit,
                          kcal: kcal, fat: fat, carbs: carbs, protein: protein,
                          fiber: Self.round(fiber, toNearest: 1),
                          sodium: Self.round(sodium, toNearest: 50),
                          sugar: Self.round(sugar, toNearest: 1),
                          nutritionConfidence: .estimated)
    }

    private static func round(_ value: Double, toNearest step: Double) -> Double {
        (value / step).rounded() * step
    }
}
