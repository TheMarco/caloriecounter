// App-wide constants — the Swift port of the values the iOS app actually needs
// from `src/lib/constants.ts`: default/min/max macro targets, the food-unit
// vocabulary, recent-food/search limits, and quantity validation bounds.
// (Web-only concerns — PWA cache, IndexedDB names, chart colors, message
// strings — are intentionally not ported.)

import Foundation

public enum Constants {
    // MARK: - Calorie target (kcal)
    public static let defaultCalorieTarget: Double = 2000
    public static let minCalorieTarget: Double = 1000
    public static let maxCalorieTarget: Double = 5000

    // MARK: - Macro targets (grams)
    public static let defaultFatTarget: Double = 65       // ~30% of 2000 kcal
    public static let defaultCarbsTarget: Double = 250    // ~50% of 2000 kcal
    public static let defaultProteinTarget: Double = 100  // ~20% of 2000 kcal

    public static let minFatTarget: Double = 20
    public static let maxFatTarget: Double = 300       // room for keto (high fat)
    public static let minCarbsTarget: Double = 20      // room for keto / very low carb
    public static let maxCarbsTarget: Double = 500
    public static let minProteinTarget: Double = 30
    public static let maxProteinTarget: Double = 300

    // MARK: - Food units (web `FOOD_UNITS`)
    public static let foodUnits: [String] = [
        "g", "ml", "cup", "tbsp", "tsp", "piece",
        "slice", "bowl", "plate", "serving", "oz", "lb",
    ]

    // MARK: - Lists & search (web `UI_CONFIG.MAX_RECENT_FOODS`, `searchPreviousFood`)
    /// Recent-foods shown for autocomplete.
    public static let maxRecentFoods = 10
    /// Default cap for `searchPreviousFoods` (web `searchPreviousFood` `limit = 15`).
    public static let searchResultLimit = 15
    /// Minimum query length before searching (web `query.length < 2` guard).
    public static let minSearchQueryLength = 2

    // MARK: - Validation (web `VALIDATION`)
    public static let minFoodNameLength = 2
    public static let maxFoodNameLength = 100
    public static let minQuantity: Double = 0.1
    public static let maxQuantity: Double = 10000
    public static let minCalories: Double = 0
    public static let maxCalories: Double = 10000

    // MARK: - Workout offsets (Apple Health)
    /// A workout must run at least this long to be offered as a calorie offset —
    /// keeps brief incidental movement (a few flights of stairs) out.
    public static let minWorkoutMinutes = 10
    /// …and must have burned at least this much active energy.
    public static let minWorkoutKcal: Double = 80
    /// How far back to look for un-offered workouts when the app comes forward.
    public static let workoutLookbackHours = 24
    /// Drop handled-workout ledger entries older than this (keeps it from growing).
    public static let workoutLedgerRetentionDays = 35

    // MARK: - Target clamping
    public static func clamp(_ value: Double, min lower: Double, max upper: Double) -> Double {
        Swift.min(Swift.max(value, lower), upper)
    }

    public static func clampedCalorieTarget(_ value: Double) -> Double {
        clamp(value, min: minCalorieTarget, max: maxCalorieTarget)
    }

    public static func clampedFatTarget(_ value: Double) -> Double {
        clamp(value, min: minFatTarget, max: maxFatTarget)
    }

    public static func clampedCarbsTarget(_ value: Double) -> Double {
        clamp(value, min: minCarbsTarget, max: maxCarbsTarget)
    }

    public static func clampedProteinTarget(_ value: Double) -> Double {
        clamp(value, min: minProteinTarget, max: maxProteinTarget)
    }
}
