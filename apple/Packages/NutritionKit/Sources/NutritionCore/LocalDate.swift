// Local-day date keys — the Swift port of the date helpers in `src/utils/idb.ts`
// (`formatLocalDate`, `todayKey`, and the day-walking loops inside
// `getDailyTotals` / `getDailyMacroTotals*`).
//
// The web app keys every entry by the user's LOCAL calendar day (not UTC), so we
// bucket with `Calendar.current` and format `YYYY-MM-DD` exactly like
// `formatLocalDate` (zero-padded, no timezone suffix). Callers may inject a
// `Calendar` for deterministic tests.

import Foundation

public enum LocalDate {
    /// `YYYY-MM-DD` for a given instant in the supplied calendar's timezone.
    /// Mirrors web `formatLocalDate(date)`.
    public static func key(for date: Date, calendar: Calendar = .current) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    /// Today's local key. Mirrors web `todayKey()`.
    public static func today(calendar: Calendar = .current, now: Date = Date()) -> String {
        key(for: now, calendar: calendar)
    }

    /// Parse a `YYYY-MM-DD` key back into a `Date` (midnight, calendar's timezone).
    public static func date(from key: String, calendar: Calendar = .current) -> Date? {
        let parts = key.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        var c = DateComponents()
        c.year = parts[0]; c.month = parts[1]; c.day = parts[2]
        return calendar.date(from: c)
    }

    /// Inclusive count of calendar days from `start` to `end` (both `YYYY-MM-DD`),
    /// e.g. same day → 1. Returns 1 if either key is malformed or `end` precedes
    /// `start`. Used to size the "All" history range from the earliest entry.
    public static func dayCount(from start: String, to end: String, calendar: Calendar = .current) -> Int {
        guard let s = date(from: start, calendar: calendar),
              let e = date(from: end, calendar: calendar) else { return 1 }
        let diff = calendar.dateComponents([.day], from: s, to: e).day ?? 0
        return max(1, diff + 1)
    }

    /// The keys for the last `days` calendar days ending on `endingOn` (inclusive),
    /// returned OLDEST-FIRST to match the chart-ready order of `getDailyTotals`
    /// (which builds newest→oldest then `.reverse()`s). Returns `[]` for `days <= 0`.
    public static func lastDays(
        _ days: Int,
        endingOn endDate: Date = Date(),
        calendar: Calendar = .current
    ) -> [String] {
        guard days > 0 else { return [] }
        var keys: [String] = []
        keys.reserveCapacity(days)
        for offset in 0..<days {
            if let day = calendar.date(byAdding: .day, value: -offset, to: endDate) {
                keys.append(key(for: day, calendar: calendar))
            }
        }
        return keys.reversed()
    }
}
