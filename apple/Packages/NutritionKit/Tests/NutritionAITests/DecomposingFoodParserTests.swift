// DecomposingFoodParser is the long-tail fallback: the model itemizes a described
// meal into ingredients + grams, each grounds against the USDA database, and the
// totals are summed IN CODE. The model call needs a device, so these tests drive
// the pure assemble() step with a fixed ComposedFood, plus the availability guard.

import Testing
@testable import NutritionAI
import NutritionCore

@Suite("DecomposingFoodParser")
struct DecomposingFoodParserTests {

    private func makeDB() -> FoodDatabase {
        FoodDatabase(foods: [
            DBFood(name: "Bread, white", kind: .food, kcal: 270, protein: 9, fat: 3.6, carbs: 49, sodium: 490),
            DBFood(name: "Bacon, cooked", kind: .food, kcal: 540, protein: 37, fat: 42, carbs: 1, sodium: 1700),
        ])
    }

    @Test("assemble grounds each ingredient against the DB, drops 0g, and sums in code")
    func assembleGroundsAndSums() {
        let parser = DecomposingFoodParser(database: makeDB())
        let composed = ComposedFood(dishName: "BLT", ingredients: [
            Ingredient(food: "white bread", grams: 60),
            Ingredient(food: "bacon", grams: 20),
            Ingredient(food: "mystery sauce", grams: 10),   // not in DB → grams-only
            Ingredient(food: "garnish", grams: 0),          // dropped
        ])
        let p = parser.assemble(composed, name: "a BLT")
        #expect(p.food == "a BLT")                          // keeps the user's wording
        #expect(p.components?.count == 3)                   // the 0g ingredient is dropped
        #expect(p.kcal == 270)                              // bread 162 + bacon 108 + sauce 0
        #expect(abs(p.protein - 12.8) < 0.01)               // bread 5.4 + bacon 7.4
        #expect(p.nutritionConfidence == .estimated)
        #expect(p.notes?.contains("3 ingredients") == true)

        let sauce = p.components?.first { $0.name == "mystery sauce" }
        #expect(sauce?.kcal == 0)                           // unresolved → grams-only, never fabricated
        #expect(sauce?.grams == 10)
    }

    @Test("a chili cheese dog decomposes into bun + dog + chili + cheese, all grounded and summed")
    func chiliCheeseDog() {
        let db = FoodDatabase(foods: [
            DBFood(name: "Hot dog bun, white", kind: .food, kcal: 267, protein: 9, fat: 4, carbs: 48, sodium: 480),
            DBFood(name: "Hot dog, beef", kind: .dish, kcal: 290, protein: 11, fat: 26, carbs: 2, sodium: 870),
            DBFood(name: "Chili con carne", kind: .food, kcal: 107, protein: 7, fat: 4, carbs: 11, sodium: 350),
            DBFood(name: "Cheese, cheddar", kind: .food, kcal: 403, protein: 23, fat: 33, carbs: 3, sodium: 620),
        ])
        // What the on-device model would itemize "chili cheese dog" into, with grams.
        let composed = ComposedFood(dishName: "chili cheese dog", ingredients: [
            Ingredient(food: "hot dog bun", grams: 45),
            Ingredient(food: "beef hot dog", grams: 50),
            Ingredient(food: "chili con carne", grams: 60),
            Ingredient(food: "cheddar cheese", grams: 20),
        ])
        let p = DecomposingFoodParser(database: db).assemble(composed, name: "chili cheese dog")
        #expect(p.components?.count == 4)
        // Every part grounded against the DB (none fell back to grams-only / 0 kcal) —
        // crucially including the cheese the single-dish match used to drop.
        #expect(p.components?.allSatisfy { $0.kcal > 0 } == true)
        #expect(p.components?.contains { $0.name == "cheddar cheese" && $0.kcal == 81 } == true)  // 403 × 0.20
        // bun 120 + dog 145 + chili 64 + cheese 81 ≈ 410.
        #expect(p.kcal == 410)
    }

    @Test("parse throws .unavailable when Foundation Models is unavailable (no model call)")
    func parseGuardsUnavailable() async {
        guard !FoundationModelsFoodParser.isAvailable else { return }   // skip where the model IS usable
        await #expect(throws: FoundationModelsError.unavailable) {
            _ = try await DecomposingFoodParser(database: makeDB()).parse(text: "grandma's stew", units: .metric)
        }
    }
}
