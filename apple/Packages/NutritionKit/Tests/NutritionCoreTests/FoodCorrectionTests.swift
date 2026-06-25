// FoodCorrection: the per-food memory of *your* numbers. The key normalizes food
// name + unit so re-logging the same thing (any casing/spacing) finds your prior
// correction. Pure value type — tested here; persistence is in NutritionStore.

import Testing
import Foundation
@testable import NutritionCore

@Suite("FoodCorrection")
struct FoodCorrectionTests {

    @Test("the key normalizes case and surrounding whitespace of the food name")
    func keyNormalizesFood() {
        #expect(FoodCorrection.key(food: "Banana", unit: "piece")
                == FoodCorrection.key(food: " banana ", unit: "piece"))
        #expect(FoodCorrection.key(food: "GREEK Yogurt", unit: "g")
                == FoodCorrection.key(food: "greek yogurt", unit: "g"))
    }

    @Test("the key normalizes the unit too, but distinguishes different units")
    func keyNormalizesUnit() {
        #expect(FoodCorrection.key(food: "rice", unit: "G")
                == FoodCorrection.key(food: "rice", unit: " g "))
        #expect(FoodCorrection.key(food: "rice", unit: "g")
                != FoodCorrection.key(food: "rice", unit: "oz"))
    }

    @Test("different foods get different keys")
    func keyDistinguishesFoods() {
        #expect(FoodCorrection.key(food: "apple", unit: "g")
                != FoodCorrection.key(food: "banana", unit: "g"))
    }

    @Test("a correction carries the corrected numbers and its key")
    func carriesNumbers() {
        let c = FoodCorrection(food: "Banana", unit: "piece",
                               kcal: 100, fat: 0.4, carbs: 27, protein: 1.3,
                               fiber: 3, sodium: 1, sugar: 14,
                               updatedAt: Date(timeIntervalSince1970: 0))
        #expect(c.key == FoodCorrection.key(food: "banana", unit: "piece"))
        #expect(c.kcal == 100)
        #expect(c.fiber == 3)
        // Codable round-trips.
        let data = try! JSONEncoder().encode(c)
        let back = try! JSONDecoder().decode(FoodCorrection.self, from: data)
        #expect(back == c)
    }
}
