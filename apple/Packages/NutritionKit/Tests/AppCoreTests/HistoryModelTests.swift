// HistoryModel loading + chart series + calendar month layout.

import Testing
import Foundation
@testable import AppCore
import NutritionCore
import NutritionStore

@MainActor
@Suite("HistoryModel")
struct HistoryModelTests {

    private func makeStore() throws -> SwiftDataStore { try SwiftDataStore.make(inMemory: true) }

    @Test("load fetches the range's daily rows oldest-first")
    func loadRange() async throws {
        let store = try makeStore()
        let keys = LocalDate.lastDays(7)            // oldest-first
        try await store.add(Entry(id: "today", date: keys.last!, timestamp: Date(timeIntervalSince1970: 0),
                                  food: "F", quantity: 1, unit: "g", kcal: 500, fat: 0, carbs: 0, protein: 0, method: .text))

        let model = HistoryModel(store: store, range: .week)
        await model.load()
        #expect(model.days.count == 7)
        #expect(model.days.map(\.date) == keys)
        #expect(model.days.last?.totals.calories == 500)
    }

    @Test("series maps the chosen macro and flags over-target days")
    func series() async throws {
        let store = try makeStore()
        let keys = LocalDate.lastDays(2)
        try await store.add(Entry(id: "a", date: keys[0], timestamp: Date(timeIntervalSince1970: 0),
                                  food: "A", quantity: 1, unit: "g", kcal: 1500, fat: 0, carbs: 0, protein: 0, method: .text))
        try await store.add(Entry(id: "b", date: keys[1], timestamp: Date(timeIntervalSince1970: 0),
                                  food: "B", quantity: 1, unit: "g", kcal: 2500, fat: 0, carbs: 0, protein: 0, method: .text))

        let model = HistoryModel(store: store, range: .week)
        model.range = .week
        await model.load()
        let points = model.series(.calories, targets: MacroTargets(calories: 2000, fat: 65, carbs: 250, protein: 100))
        let byDate = Dictionary(uniqueKeysWithValues: points.map { ($0.date, $0) })
        #expect(byDate[keys[0]]?.value == 1500)
        #expect(byDate[keys[0]]?.isOverTarget == false)
        #expect(byDate[keys[1]]?.isOverTarget == true)       // 2500 > 2000
    }

    @Test("the All range spans from the earliest entry to today")
    func loadAllRange() async throws {
        let store = try makeStore()
        // An entry 120 days ago — beyond the 90-day preset, so only "All" includes it.
        let oldKey = LocalDate.lastDays(120).first!
        try await store.add(Entry(id: "old", date: oldKey, timestamp: Date(timeIntervalSince1970: 0),
                                  food: "Old", quantity: 1, unit: "g", kcal: 700, fat: 0, carbs: 0, protein: 0, method: .text))

        let model = HistoryModel(store: store, range: .all)
        await model.load()
        #expect(model.days.count == 120)                  // earliest → today, inclusive
        #expect(model.days.first?.date == oldKey)
        #expect(model.days.first?.totals.calories == 700)
    }

    @Test("the All range falls back to a week when there is no data")
    func loadAllRangeEmpty() async throws {
        let model = HistoryModel(store: try makeStore(), range: .all)
        await model.load()
        #expect(model.days.count == 7)
    }

    @Test("load surfaces weight points in the range and the latest weight")
    func loadWeights() async throws {
        let store = try makeStore()
        let keys = LocalDate.lastDays(7)
        try await store.addWeight(WeightEntry(id: WeightEntry.id(for: keys[0]), date: keys[0],
                                              timestamp: Date(timeIntervalSince1970: 1), weightKg: 83.0))
        try await store.addWeight(WeightEntry(id: WeightEntry.id(for: keys[6]), date: keys[6],
                                              timestamp: Date(timeIntervalSince1970: 2), weightKg: 81.5))

        let model = HistoryModel(store: store, range: .week)
        await model.load()
        #expect(model.weightPoints.map(\.date) == [keys[0], keys[6]])   // oldest-first, in window
        #expect(model.weightPoints.last?.weightKg == 81.5)
        #expect(model.latestWeightKg == 81.5)
    }

    @Test("datesWithEntries lists only days that have logged food")
    func datesWithEntries() async throws {
        let store = try makeStore()
        let keys = LocalDate.lastDays(7)
        try await store.add(Entry(id: "x", date: keys[3], timestamp: Date(timeIntervalSince1970: 0),
                                  food: "X", quantity: 1, unit: "g", kcal: 100, fat: 0, carbs: 0, protein: 0, method: .text))
        let model = HistoryModel(store: store, range: .week)
        await model.load()
        #expect(model.datesWithEntries == [keys[3]])
    }

    @Test("RangeInsights averages only logged days and counts protein shortfalls")
    func rangeInsights() {
        let targets = MacroTargets(calories: 2000, fat: 65, carbs: 250, protein: 100)
        let days = [
            DayTotals(date: "2026-06-20", totals: MacroTotals(calories: 1800, protein: 120), offset: 0),
            DayTotals(date: "2026-06-21", totals: MacroTotals(calories: 2200, protein: 80), offset: 0),
            DayTotals(date: "2026-06-22", totals: .zero, offset: 0),   // not logged
        ]
        let i = RangeInsights.from(days: days, targets: targets)
        #expect(i.loggedDays == 2)               // the blank day is excluded from averages
        #expect(i.totalDays == 3)
        #expect(i.avgCalories == 2000)           // (1800 + 2200) / 2
        #expect(i.avgProtein == 100)             // (120 + 80) / 2
        #expect(i.proteinShortDays == 1)         // only the 80g day is under 100
        #expect(i.calorieDelta == 0)
        #expect(i.hasData)
    }

    @Test("History uses net calories — the chart bar and insight average subtract the day's offset")
    func netCaloriesInHistory() async throws {
        let store = try makeStore()
        let keys = LocalDate.lastDays(2)
        try await store.add(Entry(id: "big", date: keys[1], timestamp: Date(timeIntervalSince1970: 0),
                                  food: "Big day", quantity: 1, unit: "g", kcal: 2500, fat: 0, carbs: 0, protein: 0, method: .text))
        try await store.setOffset(500, on: keys[1])   // logged a 500 kcal workout

        let model = HistoryModel(store: store, range: .week)
        await model.load()
        let targets = MacroTargets(calories: 2000, fat: 65, carbs: 250, protein: 100)

        // Chart bar is net (2500 − 500 = 2000), so an on-target day reads on-target.
        let point = model.series(.calories, targets: targets).first { $0.date == keys[1] }
        #expect(point?.value == 2000)                  // not the raw 2500
        #expect(point?.isOverTarget == false)          // raw 2500 would have flagged over
        // The insight average uses net too.
        #expect(model.insights(targets: targets).avgCalories == 2000)
    }

    @Test("RangeInsights reports no data when nothing was logged")
    func rangeInsightsEmpty() {
        let targets = MacroTargets(calories: 2000, fat: 65, carbs: 250, protein: 100)
        let i = RangeInsights.from(days: [DayTotals(date: "2026-06-22", totals: .zero, offset: 0)], targets: targets)
        #expect(!i.hasData)
        #expect(i.loggedDays == 0)
        #expect(i.avgCalories == 0)
    }

    @Test("MacroKind reads each macro's value, target, and label correctly")
    func macroKindMapping() {
        let totals = MacroTotals(calories: 500, fat: 10, carbs: 20, protein: 30)
        let targets = MacroTargets(calories: 2000, fat: 65, carbs: 250, protein: 100)
        #expect(MacroKind.calories.value(in: totals) == 500)
        #expect(MacroKind.fat.value(in: totals) == 10)
        #expect(MacroKind.carbs.value(in: totals) == 20)
        #expect(MacroKind.protein.value(in: totals) == 30)
        #expect(MacroKind.calories.target(in: targets) == 2000)
        #expect(MacroKind.fat.target(in: targets) == 65)
        #expect(MacroKind.carbs.target(in: targets) == 250)
        #expect(MacroKind.protein.target(in: targets) == 100)
        #expect(MacroKind.allCases.map(\.label) == ["Calories", "Fat", "Carbs", "Protein"])
        #expect(MacroKind.calories.unit == "kcal")
        #expect(MacroKind.fat.unit == "g")
    }

    @Test("CalendarMonth computes day count and leading blanks for a fixed calendar")
    func calendarMonth() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        cal.firstWeekday = 1   // Sunday

        // June 2026: 30 days; June 1 2026 is a Monday → 1 leading blank (Sunday).
        let june = CalendarMonth(year: 2026, month: 6, calendar: cal)
        #expect(june?.dayCount == 30)
        #expect(june?.leadingBlanks == 1)
        #expect(june?.dateKey(day: 5) == "2026-06-05")

        // February 2026: 28 days (non-leap).
        #expect(CalendarMonth(year: 2026, month: 2, calendar: cal)?.dayCount == 28)
    }
}
