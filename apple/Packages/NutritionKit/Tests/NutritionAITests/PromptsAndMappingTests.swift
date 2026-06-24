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

    @Test("no USDA references → the instructions carry no reference block")
    func noReferenceBlock() {
        let text = Prompts.foodInstructions(units: .metric)
        #expect(!text.contains("REFERENCE NUTRITION DATA"))
    }

    @Test("USDA references are injected as authoritative per-100g grounding")
    func referenceBlockGrounding() {
        let refs = [
            DBFood(name: "Apples, fuji, with skin, raw", kcal: 58, protein: 0.1, fat: 0.2, carbs: 15.7, fiber: 2.1, sodium: 1, sugar: 13.3),
            DBFood(name: "Salmon, Atlantic, farmed, cooked", kcal: 206, protein: 22, fat: 12, carbs: 0, fiber: nil, sodium: 61, sugar: nil),
        ]
        let text = Prompts.foodInstructions(units: .metric, references: refs)
        #expect(text.contains("REFERENCE NUTRITION DATA"))
        #expect(text.contains("Apples, fuji, with skin, raw"))
        #expect(text.contains("58 kcal"))
        #expect(text.contains("scale"))                 // tells the model to scale, not copy
        // Unknown nutrients are simply omitted, never printed as a fake 0.
        #expect(text.contains("Salmon, Atlantic, farmed, cooked"))
    }

    @Test("barcode estimate instructions reference the product name and realistic servings")
    func barcodeInstructions() {
        let text = Prompts.barcodeInstructions
        #expect(text.lowercased().contains("serving"))
        #expect(!text.isEmpty)
    }

    @Test("NutritionInfo maps macros 1:1 to ParsedFood and tags the estimate")
    func mapping() {
        let info = NutritionInfo(food: "Oatmeal", quantity: 1, unit: "bowl",
                                 kcal: 300, fat: 6, carbs: 54, protein: 10)
        #expect(info.toParsedFood() == ParsedFood(food: "Oatmeal", quantity: 1, unit: "bowl",
                                                  kcal: 300, fat: 6, carbs: 54, protein: 10,
                                                  fiber: 0, sodium: 0, sugar: 0,
                                                  nutritionConfidence: .estimated))
    }

    @Test("toParsedFood rounds fiber/sodium/sugar estimates (no false precision)")
    func nutritionInfoRounding() {
        let info = NutritionInfo(food: "Lentil Soup", quantity: 1, unit: "bowl",
                                 kcal: 230, fat: 2, carbs: 40, protein: 18,
                                 fiber: 3.27, sodium: 873, sugar: 1.4)
        let p = info.toParsedFood()
        #expect(p.fiber == 3)        // nearest 1 g
        #expect(p.sodium == 850)     // nearest 50 mg
        #expect(p.sugar == 1)        // nearest 1 g
        #expect(p.nutritionConfidence == .estimated)
    }
}
