// FoodComponent is the transient breakdown line that rides on ParsedFood through
// the confirm sheet. These pin its Codable shape, proportional rescaling, and the
// ParsedFood.totaledFromComponents() recompute (with unknown-stays-unknown semantics).

import Testing
import Foundation
@testable import NutritionCore

@Suite("FoodComponent + ParsedFood breakdown")
struct FoodComponentTests {

    @Test("Codable round-trips, including optional nutrients")
    func codable() throws {
        let c = FoodComponent(name: "Bacon", grams: 16, kcal: 84, fat: 7, carbs: 0.2, protein: 5,
                              fiber: 0, sodium: 270, sugar: nil)
        let data = try JSONEncoder().encode(c)
        #expect(try JSONDecoder().decode(FoodComponent.self, from: data) == c)
    }

    @Test("scaled() rescales every value proportionally")
    func scaled() {
        let c = FoodComponent(name: "Bacon", grams: 16, kcal: 80, fat: 8, carbs: 0, protein: 4, sodium: 200, sugar: nil)
        let s = c.scaled(toGrams: 32)
        #expect(s.grams == 32 && s.kcal == 160 && s.sodium == 400)
        #expect(s.sugar == nil)            // unknown stays unknown
    }

    @Test("totaledFromComponents sums macros; a context nutrient is nil unless reported")
    func totaled() {
        let p = ParsedFood(food: "BLT", quantity: 1, unit: "serving", kcal: 999,  // wrong on purpose
                           fiber: nil, sodium: nil,
                           components: [
                               FoodComponent(name: "Bacon", grams: 16, kcal: 80, fat: 7, carbs: 0, protein: 5, sodium: 200),
                               FoodComponent(name: "Bread", grams: 60, kcal: 160, fat: 2, carbs: 30, protein: 6, fiber: 2, sodium: 300),
                           ]).totaledFromComponents()
        #expect(p.kcal == 240)
        #expect(p.protein == 11)
        #expect(p.fiber == 2)              // only bread reports fiber
        #expect(p.sodium == 500)
    }

    @Test("no components → unchanged")
    func noComponents() {
        let p = ParsedFood(food: "Apple", quantity: 1, unit: "piece", kcal: 95)
        #expect(p.totaledFromComponents() == p)
    }
}
