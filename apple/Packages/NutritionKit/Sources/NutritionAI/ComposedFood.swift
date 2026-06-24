// The guided-generation type for DECOMPOSING a described meal into ingredients
// (Foundation Models). The model only names ingredients and estimates their gram
// weights — the two things a small on-device model does well. It is told NOT to
// produce nutrition numbers; those come from the USDA database, summed in code
// (see DecomposingFoodParser). This is the "describe literally any food" fallback
// for meals that aren't already a row in the database.
//
// Explicit memberwise inits are declared so the types are constructible in tests
// (the decomposition→ground→sum logic is unit-tested without invoking the model).

import Foundation
import FoundationModels

@Generable(description: "A described meal broken into its component ingredients with realistic gram weights")
public struct ComposedFood: Sendable {
    @Guide(description: "Standardized dish name, no brand")
    public var dishName: String
    @Guide(description: "The ingredients that make up the whole dish, each with a realistic weight in grams")
    public var ingredients: [Ingredient]

    public init(dishName: String, ingredients: [Ingredient]) {
        self.dishName = dishName
        self.ingredients = ingredients
    }
}

@Generable(description: "One ingredient of a dish, named generically with its weight in grams")
public struct Ingredient: Sendable {
    @Guide(description: "Short generic ingredient name, no brand (e.g. 'white bread', 'bacon', 'mayonnaise')")
    public var food: String
    @Guide(description: "This ingredient's weight in grams for the whole dish", .range(0...3000))
    public var grams: Double

    public init(food: String, grams: Double) {
        self.food = food
        self.grams = grams
    }
}
