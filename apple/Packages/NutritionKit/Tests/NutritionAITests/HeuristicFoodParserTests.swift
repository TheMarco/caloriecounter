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
}
