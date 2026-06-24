// MacroMath: net-calorie clamping and the proportional quantity recalculation
// ported from EditEntryDialog.tsx.

import Testing
import Foundation
@testable import NutritionCore

@Suite("MacroMath")
struct MacroMathTests {

    // MARK: - netCalories

    @Test("netCalories subtracts the offset")
    func netCaloriesSubtracts() {
        #expect(MacroMath.netCalories(total: 2000, offset: 500) == 1500)
    }

    @Test("netCalories never goes below zero")
    func netCaloriesClampsAtZero() {
        #expect(MacroMath.netCalories(total: 300, offset: 800) == 0)
    }

    // MARK: - caloriesPerUnit

    @Test("caloriesPerUnit divides, guarding zero quantity")
    func caloriesPerUnit() {
        #expect(MacroMath.caloriesPerUnit(kcal: 248, quantity: 100) == 2.48)
        #expect(MacroMath.caloriesPerUnit(kcal: 248, quantity: 0) == 0)
    }

    // MARK: - recalculatedCalories (EditEntryDialog rule)

    @Test("recalculatedCalories scales and rounds like the web dialog")
    func recalculatedCaloriesRounds() {
        // perUnit = 248/150 = 1.6533…; ×200 = 330.66… → 331
        let kcal = MacroMath.recalculatedCalories(
            forQuantity: 200, originalKcal: 248, originalQuantity: 150
        )
        #expect(kcal == 331)
    }

    @Test("recalculatedCalories returns 0 when new quantity is 0")
    func recalculatedCaloriesZeroQuantity() {
        #expect(MacroMath.recalculatedCalories(forQuantity: 0, originalKcal: 248, originalQuantity: 150) == 0)
    }

    // MARK: - scaled(entry:)

    @Test("scaled doubles nutrition when quantity doubles")
    func scaledDoublesNutrition() {
        let entry = Entry(
            id: "e1", date: "2026-06-22", timestamp: Date(timeIntervalSince1970: 0),
            food: "Brown Rice", quantity: 100, unit: "g",
            kcal: 111, fat: 0.9, carbs: 23, protein: 2.6, method: .text
        )
        let scaled = MacroMath.scaled(entry, toQuantity: 200)
        #expect(scaled.quantity == 200)
        #expect(scaled.kcal == 222)                    // round(1.11 × 200)
        #expect(abs(scaled.fat - 1.8) < 1e-9)
        #expect(abs(scaled.carbs - 46) < 1e-9)
        #expect(abs(scaled.protein - 5.2) < 1e-9)
        // Identity/method are preserved.
        #expect(scaled.id == "e1")
        #expect(scaled.method == .text)
    }

    @Test("scaled to zero quantity zeroes all nutrition")
    func scaledToZero() {
        let entry = Entry(
            id: "e1", date: "2026-06-22", timestamp: Date(timeIntervalSince1970: 0),
            food: "Almonds", quantity: 30, unit: "g",
            kcal: 174, fat: 15, carbs: 6.1, protein: 6.4, method: .text
        )
        let scaled = MacroMath.scaled(entry, toQuantity: 0)
        #expect(scaled.quantity == 0)
        #expect(scaled.kcal == 0)
        #expect(scaled.fat == 0)
        #expect(scaled.carbs == 0)
        #expect(scaled.protein == 0)
    }

    @Test("scaled also scales fiber/sodium/sugar (nutrients too); unknown stays nil")
    func scaledContextNutrients() {
        let entry = Entry(
            id: "e1", date: "2026-06-22", timestamp: Date(timeIntervalSince1970: 0),
            food: "Bran", quantity: 100, unit: "g", kcal: 200, fat: 2, carbs: 40, protein: 8,
            method: .text, fiber: 12, sodium: 210, sugar: nil
        )
        let scaled = MacroMath.scaled(entry, toQuantity: 200)
        #expect(scaled.fiber == 24)
        #expect(scaled.sodium == 420)
        #expect(scaled.sugar == nil)                 // unknown is never fabricated

        let zeroed = MacroMath.scaled(entry, toQuantity: 0)
        #expect(zeroed.fiber == 0)                   // known zero
        #expect(zeroed.sugar == nil)                 // still unknown
    }
}
