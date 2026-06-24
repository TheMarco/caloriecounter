// DatabaseFoodParser is the Analyze-path resolver over the on-device USDA database:
// a confident match returns measured nutrition + breakdown while keeping the user's
// wording; no match throws so the composite parser can fall through to the model.

import Testing
@testable import NutritionAI
import NutritionCore

@Suite("DatabaseFoodParser")
struct DatabaseFoodParserTests {

    private func makeDB() -> FoodDatabase {
        FoodDatabase(foods: [
            DBFood(name: "Bacon, lettuce, tomato sandwich on white", kind: .dish,
                   kcal: 231, protein: 10.9, fat: 7.5, carbs: 29.7, sodium: 521,
                   portions: [DBPortion(label: "1 sandwich", grams: 105)],
                   recipe: [DBIngredient(name: "Bread, white", grams: 60),
                            DBIngredient(name: "Bacon", grams: 16)]),
            DBFood(name: "Bread, white", kind: .food, kcal: 270, protein: 9, fat: 3.6, carbs: 49),
        ])
    }

    @Test("a confident match resolves with measured nutrition, keeping the user's wording")
    func resolvesKeepingWording() async throws {
        let p = try await DatabaseFoodParser(database: makeDB()).parse(text: "a BLT", units: .metric)
        #expect(p.food == "a BLT")                    // the user's words, not the USDA row name
        #expect(p.kcal == 243)                        // 231/100g × 105 g
        #expect(p.components?.isEmpty == false)       // dish carries its recipe breakdown
        #expect(p.nutritionConfidence == .estimated)
    }

    @Test("no confident match throws .noMatch so a composite can fall through")
    func noMatchThrows() async {
        await #expect(throws: DatabaseLookupError.noMatch) {
            _ = try await DatabaseFoodParser(database: makeDB()).parse(text: "zzqq gibberish plate", units: .metric)
        }
    }
}
