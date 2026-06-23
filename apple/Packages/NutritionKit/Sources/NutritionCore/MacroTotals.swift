// Aggregated nutrition for a set of entries — the Swift port of `MacroTotals`
// in `src/types/index.ts`. The reduction mirrors `getMacroTotalsForDate` in
// `src/utils/idb.ts` (sum kcal/fat/carbs/protein over the day's entries).

import Foundation

public struct MacroTotals: Codable, Sendable, Equatable {
    public var calories: Double
    public var fat: Double
    public var carbs: Double
    public var protein: Double

    public init(calories: Double = 0, fat: Double = 0, carbs: Double = 0, protein: Double = 0) {
        self.calories = calories
        self.fat = fat
        self.carbs = carbs
        self.protein = protein
    }

    /// All-zero totals (web reducer's initial accumulator).
    public static let zero = MacroTotals()

    /// Accumulate a single entry's macros (web reducer step).
    public func adding(_ entry: Entry) -> MacroTotals {
        MacroTotals(
            calories: calories + entry.kcal,
            fat: fat + entry.fat,
            carbs: carbs + entry.carbs,
            protein: protein + entry.protein
        )
    }

    /// Sum a collection of entries into one total (port of `getMacroTotalsForDate`).
    public static func summing(_ entries: [Entry]) -> MacroTotals {
        entries.reduce(.zero) { $0.adding($1) }
    }

    public static func + (lhs: MacroTotals, rhs: MacroTotals) -> MacroTotals {
        MacroTotals(
            calories: lhs.calories + rhs.calories,
            fat: lhs.fat + rhs.fat,
            carbs: lhs.carbs + rhs.carbs,
            protein: lhs.protein + rhs.protein
        )
    }
}
