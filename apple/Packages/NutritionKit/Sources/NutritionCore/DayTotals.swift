// One day's aggregated nutrition plus its exercise/adjustment offset — the unit
// the History charts plot. Ported from the rows produced by
// `getDailyMacroTotalsWithOffset` in `src/utils/idb.ts`
// (`{ date, totals, offset }`, oldest-first for charting).

import Foundation

public struct DayTotals: Codable, Sendable, Equatable {
    /// Local calendar day, `YYYY-MM-DD`.
    public let date: String
    public let totals: MacroTotals
    /// Calories burned / manual adjustment for the day (web `offset:{date}`).
    public let offset: Double

    public init(date: String, totals: MacroTotals, offset: Double) {
        self.date = date
        self.totals = totals
        self.offset = offset
    }

    /// Calories consumed minus the offset, clamped at zero (see `MacroMath`).
    public var netCalories: Double {
        MacroMath.netCalories(total: totals.calories, offset: offset)
    }
}
