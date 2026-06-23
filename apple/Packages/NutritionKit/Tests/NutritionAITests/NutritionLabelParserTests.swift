// NutritionLabelParser turns OCR text lines from a nutrition panel into a
// ParsedFood. The Vision OCR step (VisionLabelReader) runs on-device and is
// validated in Phase 11; this suite locks the deterministic line-parsing regexes.

import Testing
@testable import NutritionAI
import NutritionCore

@Suite("NutritionLabelParser")
struct NutritionLabelParserTests {

    @Test("parses a standard US nutrition panel")
    func standardPanel() throws {
        let lines = ["Nutrition Facts", "Serving size 1 cup", "Calories 250",
                     "Total Fat 12g", "Total Carbohydrate 30g", "Protein 9g"]
        let food = try #require(NutritionLabelParser.parse(lines: lines))
        #expect(food.kcal == 250)
        #expect(food.fat == 12)
        #expect(food.carbs == 30)
        #expect(food.protein == 9)
        #expect(food.unit == "serving")
        #expect(food.quantity == 1)
    }

    @Test("is case-insensitive and tolerates colons and decimals")
    func colonsAndDecimals() throws {
        let lines = ["calories: 180", "fat 3.5 g", "carbohydrates: 22 g", "PROTEIN 6.2G"]
        let food = try #require(NutritionLabelParser.parse(lines: lines))
        #expect(food.kcal == 180)
        #expect(food.fat == 3.5)
        #expect(food.carbs == 22)
        #expect(food.protein == 6.2)
    }

    @Test("does not confuse 'sugars' with carbohydrates or 'saturated fat' totals")
    func avoidsFalsePositives() throws {
        let lines = ["Calories 100", "Total Fat 0g", "Saturated Fat 0g",
                     "Total Carbohydrate 25g", "Sugars 20g", "Protein 0g"]
        let food = try #require(NutritionLabelParser.parse(lines: lines))
        #expect(food.carbs == 25)     // not 20 (sugars)
        #expect(food.fat == 0)
    }

    @Test("returns nil when there is no calorie line to anchor on")
    func noCalories() {
        #expect(NutritionLabelParser.parse(lines: ["Ingredients: water, salt"]) == nil)
        #expect(NutritionLabelParser.parse(lines: []) == nil)
    }

    @Test("missing macros default to zero but a calorie value still yields a result")
    func partialPanel() throws {
        let food = try #require(NutritionLabelParser.parse(lines: ["Calories 90"]))
        #expect(food.kcal == 90)
        #expect(food.fat == 0)
        #expect(food.carbs == 0)
        #expect(food.protein == 0)
    }

    @Test("extracts dietary fiber, sodium (mg), and total sugars; tags .label")
    func fiberSodiumSugar() throws {
        let lines = ["Calories 240", "Total Fat 9g", "Total Carbohydrate 41g",
                     "Dietary Fiber 7g", "Total Sugars 12g", "Sodium 350mg", "Protein 5g"]
        let food = try #require(NutritionLabelParser.parse(lines: lines))
        #expect(food.fiber == 7)
        #expect(food.sodium == 350)
        #expect(food.sugar == 12)
        #expect(food.nutritionConfidence == .label)
    }

    @Test("fiber/sodium/sugar stay nil when the panel omits them")
    func nutrientsOptional() throws {
        let food = try #require(NutritionLabelParser.parse(lines: ["Calories 90", "Protein 2g"]))
        #expect(food.fiber == nil && food.sodium == nil && food.sugar == nil)
    }
}
