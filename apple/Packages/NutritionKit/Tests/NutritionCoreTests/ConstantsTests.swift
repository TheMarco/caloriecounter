// Constants: default targets and clamping ranges match src/lib/constants.ts;
// the food-unit vocabulary and DateRange presets are stable.

import Testing
@testable import NutritionCore

@Suite("Constants")
struct ConstantsTests {

    @Test("default targets match the web app")
    func defaultTargets() {
        #expect(Constants.defaultCalorieTarget == 2000)
        #expect(Constants.defaultFatTarget == 65)
        #expect(Constants.defaultCarbsTarget == 250)
        #expect(Constants.defaultProteinTarget == 100)
    }

    @Test("MacroTargets.default composes the web defaults")
    func macroTargetsDefault() {
        #expect(MacroTargets.default == MacroTargets(calories: 2000, fat: 65, carbs: 250, protein: 100))
    }

    @Test("food units match FOOD_UNITS exactly and in order")
    func foodUnits() {
        #expect(Constants.foodUnits == [
            "g", "ml", "cup", "tbsp", "tsp", "piece",
            "slice", "bowl", "plate", "serving", "oz", "lb",
        ])
    }

    @Test("calorie target clamps to [1000, 5000]")
    func calorieClamp() {
        #expect(Constants.clampedCalorieTarget(500) == 1000)
        #expect(Constants.clampedCalorieTarget(9000) == 5000)
        #expect(Constants.clampedCalorieTarget(2200) == 2200)
    }

    @Test("each macro target clamps to its own range")
    func macroClamps() {
        #expect(Constants.clampedFatTarget(5) == 20)
        #expect(Constants.clampedFatTarget(999) == 200)
        #expect(Constants.clampedCarbsTarget(10) == 50)
        #expect(Constants.clampedCarbsTarget(999) == 500)
        #expect(Constants.clampedProteinTarget(10) == 30)
        #expect(Constants.clampedProteinTarget(999) == 300)
    }

    @Test("MacroTargets.clamped clamps every field at once")
    func macroTargetsClamped() {
        let wild = MacroTargets(calories: 100, fat: 999, carbs: 1, protein: 999).clamped
        #expect(wild == MacroTargets(calories: 1000, fat: 200, carbs: 50, protein: 300))
    }

    @Test("DateRange presets carry the web day counts and labels")
    func dateRangePresets() {
        #expect(DateRange.allCases.map(\.rawValue) == ["7d", "30d", "90d"])
        #expect(DateRange.week.days == 7)
        #expect(DateRange.month.days == 30)
        #expect(DateRange.quarter.days == 90)
        #expect(DateRange.week.label == "7 Days")
    }
}
