// HeuristicFoodParser is the on-device fallback used when Foundation Models is
// unavailable. Its logic is a faithful port of the `fallbackParsing` function in
// `src/app/api/parse-food/route.ts`: quantity+unit regexes first, then a
// longest-match lookup over a common-portion table, then an isDish-aware last
// resort. These tests pin that behavior.

import Testing
@testable import NutritionAI
import NutritionCore

@Suite("HeuristicFoodParser")
struct HeuristicFoodParserTests {

    @Test("a quantity+unit phrase is parsed structurally (no calorie estimate)")
    func quantityUnitRegex() {
        let food = HeuristicFoodParser.estimate("250 g brown rice", units: .metric)
        #expect(food.food == "brown rice")
        #expect(food.quantity == 250)
        #expect(food.unit == "g")
        #expect(food.kcal == 0)                          // web returns no kcal here
        #expect(food.notes?.contains("without AI") == true)
    }

    @Test("recognizes ml / tbsp / slice quantity units")
    func otherUnits() {
        #expect(HeuristicFoodParser.estimate("330 ml cola", units: .metric).unit == "ml")
        #expect(HeuristicFoodParser.estimate("2 tbsp olive oil", units: .metric).unit == "tbsp")
        #expect(HeuristicFoodParser.estimate("3 slices bread", units: .metric).unit == "slice")
    }

    @Test("a known food matches the common-portion table with a calorie estimate")
    func commonPortionMatch() {
        let food = HeuristicFoodParser.estimate("grilled chicken breast", units: .metric)
        // "chicken breast" (longer) is preferred over "chicken".
        #expect(food.food == "chicken breast")
        #expect(food.quantity == 150)
        #expect(food.unit == "g")
        #expect(food.kcal == 248)
        #expect(food.notes?.contains("Estimated portion") == true)
    }

    @Test("longer, more specific keys win the lookup")
    func longestMatchWins() {
        let food = HeuristicFoodParser.estimate("a big plate of fettuccine alfredo", units: .metric)
        #expect(food.food == "fettuccine alfredo")
        #expect(food.quantity == 350)
        #expect(food.kcal == 800)
    }

    @Test("an unknown 'plate/bowl' phrase falls back to a larger dish portion")
    func lastResortDish() {
        let food = HeuristicFoodParser.estimate("grandma's mystery stew plate", units: .metric)
        #expect(food.quantity == 250)
        #expect(food.unit == "g")
        #expect(food.kcal == 400)
        #expect(food.food == "grandma's mystery stew plate")
    }

    @Test("an unknown single item falls back to a small default portion")
    func lastResortItem() {
        let food = HeuristicFoodParser.estimate("zorblax fruit", units: .metric)
        #expect(food.quantity == 100)
        #expect(food.kcal == 150)
        #expect(food.unit == "g")
    }

    @Test("parse(text:units:) surfaces the same estimate via the FoodParsing seam")
    func parseSeam() async throws {
        let parser = HeuristicFoodParser()
        let food = try await parser.parse(text: "apple", units: .metric)
        #expect(food.food == "apple")
        #expect(food.kcal == 78)
    }

    // MARK: - USDA grounding (instance parse only; static estimate stays pure)

    private func groundedParser() -> HeuristicFoodParser {
        HeuristicFoodParser(database: FoodDatabase(foods: [
            DBFood(name: "Salmon, Atlantic, farmed, cooked", kcal: 206, protein: 22, fat: 12, carbs: 0, fiber: nil, sodium: 61, sugar: nil),
            DBFood(name: "Avocados, raw, all commercial varieties", kcal: 160, protein: 2, fat: 14.7, carbs: 8.5, fiber: 6.7, sodium: 7, sugar: 0.7),
        ]))
    }

    @Test("an explicit gram amount is grounded in USDA density")
    func gramsGrounded() async throws {
        let food = try await groundedParser().parse(text: "150 g salmon", units: .metric)
        #expect(food.quantity == 150)
        #expect(food.unit == "g")
        #expect(food.kcal == 309)                         // 206 * 1.5
        #expect(food.protein == 33)
        #expect(food.sodium == 100)                       // 91.5 → nearest 50 mg
        #expect(food.notes?.contains("USDA") == true)
    }

    @Test("a single-item fallback is grounded and gains fiber/sodium it lacked before")
    func singleItemGrounded() async throws {
        let food = try await groundedParser().parse(text: "avocado", units: .metric)
        #expect(food.unit == "g")
        #expect(food.quantity == 100)
        #expect(food.kcal == 160)                         // per-100g density, 100 g portion
        #expect(food.fiber == 7)                          // 6.7 → nearest 1 g (was nil before)
        #expect(food.nutritionConfidence == .estimated)
    }

    @Test("a dish-sized estimate is NOT grounded (raw density would mis-scale a cooked bowl)")
    func dishNotGrounded() async throws {
        // "salmon ... bowl" → 250 g dish default; must stay the conservative estimate.
        let food = try await groundedParser().parse(text: "bowl of salmon poke", units: .metric)
        #expect(food.quantity == 250)
        #expect(food.kcal == 400)                         // unchanged dish default, not USDA-scaled
        #expect(food.fiber == nil)
    }

    @Test("an unknown single item without a USDA match keeps the plain default")
    func unknownUngrounded() async throws {
        let food = try await groundedParser().parse(text: "zorblax", units: .metric)
        #expect(food.kcal == 150)
        #expect(food.fiber == nil)
    }
}
