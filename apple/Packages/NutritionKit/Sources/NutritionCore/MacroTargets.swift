// Daily macro goals — the Swift port of `MacroTargets` in `src/types/index.ts`.
// Defaults come from `src/lib/constants.ts` (2000 kcal / 65 fat / 250 carbs /
// 100 protein). Clamping ranges live in `Constants`.

import Foundation

public struct MacroTargets: Codable, Sendable, Equatable {
    public var calories: Double
    public var fat: Double
    public var carbs: Double
    public var protein: Double

    public init(calories: Double, fat: Double, carbs: Double, protein: Double) {
        self.calories = calories
        self.fat = fat
        self.carbs = carbs
        self.protein = protein
    }

    /// Web defaults: `DEFAULT_CALORIE_TARGET` / `DEFAULT_FAT_TARGET` / etc.
    public static let `default` = MacroTargets(
        calories: Constants.defaultCalorieTarget,
        fat: Constants.defaultFatTarget,
        carbs: Constants.defaultCarbsTarget,
        protein: Constants.defaultProteinTarget
    )

    /// Each target clamped to its valid web range (`MIN_*` / `MAX_*`).
    public var clamped: MacroTargets {
        MacroTargets(
            calories: Constants.clampedCalorieTarget(calories),
            fat: Constants.clampedFatTarget(fat),
            carbs: Constants.clampedCarbsTarget(carbs),
            protein: Constants.clampedProteinTarget(protein)
        )
    }
}
