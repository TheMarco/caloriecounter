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
