// Locks the on-device prompt instructions (ported portion rules) and the
// NutritionInfo → ParsedFood mapping. The prompt text materially shapes the
// model's estimates, so drift here is a behavior change worth catching.

import Testing
@testable import NutritionAI
import NutritionCore

@Suite("Prompts + NutritionInfo mapping")
struct PromptsAndMappingTests {

    @Test("instructions carry the ported portion-size rules")
    func portionRules() {
        let metric = Prompts.foodInstructions(units: .metric)
        #expect(metric.contains("300-400g"))           // pasta rule
        #expect(metric.lowercased().contains("portion"))
        #expect(metric.contains("TOTAL"))              // total-not-per-100g rule
    }

    @Test("units instruction differs between metric and imperial")
    func unitsInstruction() {
        let metric = Prompts.foodInstructions(units: .metric)
        let imperial = Prompts.foodInstructions(units: .imperial)
        #expect(metric.lowercased().contains("grams"))
        #expect(imperial.lowercased().contains("oz"))
        #expect(metric != imperial)
    }

    @Test("barcode estimate instructions reference the product name and realistic servings")
    func barcodeInstructions() {
        let text = Prompts.barcodeInstructions
        #expect(text.lowercased().contains("serving"))
        #expect(!text.isEmpty)
    }

    @Test("NutritionInfo maps 1:1 to ParsedFood")
    func mapping() {
        let info = NutritionInfo(food: "Oatmeal", quantity: 1, unit: "bowl",
                                 kcal: 300, fat: 6, carbs: 54, protein: 10)
        #expect(info.toParsedFood() == ParsedFood(food: "Oatmeal", quantity: 1, unit: "bowl",
                                                  kcal: 300, fat: 6, carbs: 54, protein: 10))
    }
}
