// LocalDate: format fidelity to web `formatLocalDate` and the day-walking order
// used by the history charts. A fixed UTC calendar makes the assertions
// deterministic regardless of the machine's timezone.

import Testing
import Foundation
@testable import NutritionCore

@Suite("LocalDate")
struct LocalDateTests {

    private var utc: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return cal
    }

    @Test("key formats YYYY-MM-DD with zero padding")
    func keyFormat() {
        // 2026-01-05T00:00:00Z
        let date = Date(timeIntervalSince1970: 1_767_571_200)
        #expect(LocalDate.key(for: date, calendar: utc) == "2026-01-05")
    }

    @Test("today uses the injected now/calendar")
    func todayUsesInjectedNow() {
        let now = Date(timeIntervalSince1970: 1_750_000_000) // 2025-06-15T...Z
        #expect(LocalDate.today(calendar: utc, now: now) == LocalDate.key(for: now, calendar: utc))
    }

    @Test("today matches the documented YYYY-MM-DD shape")
    func todayShape() {
        let key = LocalDate.today()
        #expect(key.count == 10)
        #expect(key[key.index(key.startIndex, offsetBy: 4)] == "-")
        #expect(key[key.index(key.startIndex, offsetBy: 7)] == "-")
    }

    @Test("lastDays returns `days` keys, oldest-first, ending today inclusive")
    func lastDaysOrderAndCount() {
        let end = Date(timeIntervalSince1970: 1_767_571_200) // 2026-01-05Z
        let keys = LocalDate.lastDays(3, endingOn: end, calendar: utc)
        #expect(keys == ["2026-01-03", "2026-01-04", "2026-01-05"])
    }

    @Test("lastDays crosses a month boundary correctly")
    func lastDaysMonthBoundary() {
        let end = Date(timeIntervalSince1970: 1_767_571_200) // 2026-01-05Z
        let keys = LocalDate.lastDays(7, endingOn: end, calendar: utc)
        #expect(keys.first == "2025-12-30")
        #expect(keys.last == "2026-01-05")
        #expect(keys.count == 7)
    }

    @Test("lastDays of non-positive days is empty")
    func lastDaysNonPositive() {
        #expect(LocalDate.lastDays(0, calendar: utc).isEmpty)
        #expect(LocalDate.lastDays(-5, calendar: utc).isEmpty)
    }

    @Test("dayCount is inclusive and resilient to bad input")
    func dayCountInclusive() {
        #expect(LocalDate.dayCount(from: "2026-01-01", to: "2026-01-01", calendar: utc) == 1)
        #expect(LocalDate.dayCount(from: "2026-01-01", to: "2026-01-07", calendar: utc) == 7)
        #expect(LocalDate.dayCount(from: "2025-12-30", to: "2026-01-05", calendar: utc) == 7)
        #expect(LocalDate.dayCount(from: "2026-02-10", to: "2026-02-01", calendar: utc) == 1)  // end before start
        #expect(LocalDate.dayCount(from: "garbage", to: "2026-01-05", calendar: utc) == 1)     // malformed
    }
}
