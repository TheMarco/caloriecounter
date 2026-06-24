// Pure nutrition arithmetic shared across the app.
//
// Two ported behaviors:
//  - `netCalories` = max(0, consumed − offset): the "net calories" the web shows
//    in the total card / history (calories consumed minus the day's burn offset),
//    floored at zero so a large offset never reads negative.
//  - quantity recalculation: when the user edits an entry's quantity, calories
//    scale proportionally and round to a whole number — the exact behavior of
//    `EditEntryDialog.tsx` (`kcalPerUnit = kcal/qty`, `newKcal = round(perUnit *
//    newQty)`, and `newQty == 0 → 0`). Macros scale by the same ratio.

import Foundation

public enum MacroMath {
    /// Calories consumed minus the day's offset, never below zero.
    public static func netCalories(total: Double, offset: Double) -> Double {
        max(0, total - offset)
    }

    /// Calories attributable to one unit (web `kcal / qty`; 0 when `quantity <= 0`).
    public static func caloriesPerUnit(kcal: Double, quantity: Double) -> Double {
        quantity > 0 ? kcal / quantity : 0
    }

    /// Recalculated, rounded calories for a new quantity — the `EditEntryDialog`
    /// rule: `round(perUnit * newQuantity)`, and exactly `0` when `newQuantity == 0`.
    public static func recalculatedCalories(
        forQuantity newQuantity: Double,
        originalKcal: Double,
        originalQuantity: Double
    ) -> Double {
        guard newQuantity > 0 else { return 0 }
        let perUnit = caloriesPerUnit(kcal: originalKcal, quantity: originalQuantity)
        return (perUnit * newQuantity).rounded()
    }

    /// A copy of `entry` rescaled to `newQuantity`: calories follow the rounded
    /// `EditEntryDialog` rule; fat/carbs/protein scale by the same ratio (unrounded
    /// so small portions keep their precision). `newQuantity == 0` zeroes nutrition.
    public static func scaled(_ entry: Entry, toQuantity newQuantity: Double) -> Entry {
        var result = entry
        result.quantity = newQuantity
        guard newQuantity > 0, entry.quantity > 0 else {
            result.kcal = 0
            result.fat = 0
            result.carbs = 0
            result.protein = 0
            // Context nutrients scale to a known zero, or stay unknown.
            result.fiber = entry.fiber.map { _ in 0 }
            result.sodium = entry.sodium.map { _ in 0 }
            result.sugar = entry.sugar.map { _ in 0 }
            return result
        }
        let ratio = newQuantity / entry.quantity
        result.kcal = recalculatedCalories(
            forQuantity: newQuantity,
            originalKcal: entry.kcal,
            originalQuantity: entry.quantity
        )
        result.fat = entry.fat * ratio
        result.carbs = entry.carbs * ratio
        result.protein = entry.protein * ratio
        // Fiber/sodium/sugar are nutrients too — scale them with the amount (nil stays nil).
        result.fiber = entry.fiber.map { $0 * ratio }
        result.sodium = entry.sodium.map { $0 * ratio }
        result.sugar = entry.sugar.map { $0 * ratio }
        return result
    }
}
