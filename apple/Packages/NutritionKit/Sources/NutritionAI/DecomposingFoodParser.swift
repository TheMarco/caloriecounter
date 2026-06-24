// FoodParsing for the long tail: a described meal that ISN'T already a row in the
// USDA database. The on-device model itemizes it into ingredients with gram weights
// (its strength), each ingredient is grounded against the database (real per-100g
// densities × grams), and the totals are summed IN CODE — never by the model. The
// result carries the same editable breakdown as a matched dish.
//
// Sits between the direct database match and the single-food estimate in the
// composite chain. Requires Foundation Models; throws .unavailable otherwise so the
// composite falls through (there is no heuristic decomposition).

import Foundation
import FoundationModels
import NutritionCore

public struct DecomposingFoodParser: FoodParsing {
    private let database: FoodDatabase

    public init(database: FoodDatabase = .shared) {
        self.database = database
    }

    public func parse(text: String, units: UnitSystem) async throws -> ParsedFood {
        guard FoundationModelsFoodParser.isAvailable else { throw FoundationModelsError.unavailable }
        let session = LanguageModelSession(instructions: Prompts.decompositionInstructions(units: units))
        let response = try await session.respond(to: text, generating: ComposedFood.self)
        let name = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let assembled = assemble(response.content, name: name.isEmpty ? response.content.dishName : name)
        // If nothing decomposed (or nothing grounded), let the composite fall through.
        guard let components = assembled.components, !components.isEmpty else {
            throw FoundationModelsError.unavailable
        }
        return assembled
    }

    /// Pure decomposition→ground→sum: each ingredient grounds against the database
    /// (density × grams); unresolved ingredients become grams-only lines (0 macros,
    /// never fabricated). The top-line is the sum of the components. Unit-tested.
    func assemble(_ composed: ComposedFood, name: String) -> ParsedFood {
        let components = composed.ingredients
            .filter { $0.grams > 0 }
            .map { ingredient -> FoodComponent in
                if let match = database.bestConfidentMatch(ingredient.food) {
                    let m = match.scaled(toGrams: ingredient.grams)
                    return FoodComponent(name: ingredient.food, grams: ingredient.grams,
                                         kcal: m.kcal.rounded(), fat: round1(m.fat), carbs: round1(m.carbs),
                                         protein: round1(m.protein), fiber: m.fiber.map { $0.rounded() },
                                         sodium: m.sodium.map { ($0 / 10).rounded() * 10 }, sugar: m.sugar.map { $0.rounded() })
                }
                return FoodComponent(name: ingredient.food, grams: ingredient.grams, kcal: 0)
            }

        let base = ParsedFood(
            food: name, quantity: 1, unit: "serving", kcal: 0,
            notes: "Estimated from \(components.count) ingredients",
            nutritionConfidence: .estimated,
            components: components
        )
        return base.totaledFromComponents()
    }

    private func round1(_ v: Double) -> Double { (v * 10).rounded() / 10 }
}
