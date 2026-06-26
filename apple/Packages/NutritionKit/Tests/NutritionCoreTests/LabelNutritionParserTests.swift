// LabelNutritionParser: extracting serving size + calories/protein/carbs/fat from
// the (often messy) lines Vision OCR reads off a Nutrition Facts panel.

import Testing
import Foundation
@testable import NutritionCore

@Suite("LabelNutritionParser")
struct LabelNutritionParserTests {

    @Test("Standard US Nutrition Facts panel")
    func standardPanel() throws {
        let lines = [
            "Nutrition Facts",
            "Serving size 1 cup (240ml)",
            "Calories 240",
            "Total Fat 8g",
            "Total Carbohydrate 30g",
            "Protein 12g",
        ]
        let facts = try #require(LabelNutritionParser.parse(lines: lines))
        #expect(facts.kcal == 240)
        #expect(facts.fat == 8)
        #expect(facts.carbs == 30)
        #expect(facts.protein == 12)
        #expect(facts.servingDescription.lowercased().contains("1 cup"))
    }

    @Test("Colons, decimals, and spaced units")
    func colonsAndDecimals() throws {
        let lines = [
            "Serving Size: 2 slices (56 g)",
            "Calories: 140",
            "Total Fat 2.5 g",
            "Total Carbohydrate 26 g",
            "Protein 5 g",
        ]
        let facts = try #require(LabelNutritionParser.parse(lines: lines))
        #expect(facts.kcal == 140)
        #expect(facts.fat == 2.5)
        #expect(facts.carbs == 26)
        #expect(facts.protein == 5)
        #expect(facts.servingDescription.lowercased().contains("2 slices"))
    }

    @Test("OCR splits the value onto the next line")
    func valueOnNextLine() throws {
        // Vision often emits the label and its number as separate lines.
        let lines = ["Calories", "240", "Protein", "12g"]
        let facts = try #require(LabelNutritionParser.parse(lines: lines))
        #expect(facts.kcal == 240)
        #expect(facts.protein == 12)
        // Missing fields default to 0; the comparison screen lets the user fix them.
        #expect(facts.carbs == 0)
        #expect(facts.fat == 0)
        // No serving line → a sensible default.
        #expect(facts.servingDescription == "1 serving")
    }

    @Test("Non-label text yields nil")
    func nonLabelIsNil() {
        #expect(LabelNutritionParser.parse(lines: ["Hello there", "Best before 2027", "Made in USA"]) == nil)
        #expect(LabelNutritionParser.parse(lines: []) == nil)
    }

    @Test("\"Carbs\" abbreviation and lowercase are tolerated")
    func carbsAbbreviation() throws {
        let lines = ["calories 90", "carbs 22g", "protein 0g", "fat 0g"]
        let facts = try #require(LabelNutritionParser.parse(lines: lines))
        #expect(facts.kcal == 90)
        #expect(facts.carbs == 22)
    }
}
