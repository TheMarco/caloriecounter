// TodayModel orchestration over an in-memory store, plus the MacroProgress math.

import Testing
import Foundation
@testable import AppCore
import NutritionCore
import NutritionStore

@MainActor
@Suite("TodayModel")
struct TodayModelTests {

    private func makeStore() throws -> SwiftDataStore { try SwiftDataStore.make(inMemory: true) }

    private func entry(_ id: String, kcal: Double, fat: Double = 0, carbs: Double = 0, protein: Double = 0,
                       date: String = "2026-06-22", ts: TimeInterval = 0) -> Entry {
        Entry(id: id, date: date, timestamp: Date(timeIntervalSince1970: ts), food: "F",
              quantity: 1, unit: "g", kcal: kcal, fat: fat, carbs: carbs, protein: protein, method: .text)
    }

    @Test("load aggregates the day's entries, totals, and offset")
    func load() async throws {
        let store = try makeStore()
        try await store.add(entry("a", kcal: 200, fat: 5, carbs: 10, protein: 8))
        try await store.add(entry("b", kcal: 300, fat: 2, carbs: 20, protein: 12))
        try await store.setOffset(150, on: "2026-06-22")

        let model = TodayModel(store: store, date: "2026-06-22")
        await model.load()

        #expect(model.entries.count == 2)
        #expect(model.totals == MacroTotals(calories: 500, fat: 7, carbs: 30, protein: 20))
        #expect(model.offset == 150)
        #expect(model.netCalories == 350)
    }

    @Test("deleteEntry removes the entry and refreshes totals")
    func deleteEntry() async throws {
        let store = try makeStore()
        try await store.add(entry("a", kcal: 200))
        try await store.add(entry("b", kcal: 300))
        let model = TodayModel(store: store, date: "2026-06-22")
        await model.load()

        await model.deleteEntry(id: "a")
        #expect(model.entries.map(\.id) == ["b"])
        #expect(model.totals.calories == 300)
    }

    @Test("updateOffset persists and recomputes net calories")
    func updateOffset() async throws {
        let store = try makeStore()
        try await store.add(entry("a", kcal: 600))
        let model = TodayModel(store: store, date: "2026-06-22")
        await model.load()

        await model.updateOffset(250)
        #expect(model.offset == 250)
        #expect(model.netCalories == 350)
        // Persisted: a fresh model sees it.
        let fresh = TodayModel(store: store, date: "2026-06-22")
        await fresh.load()
        #expect(fresh.offset == 250)
    }

    @Test("add persists a confirmed entry and refreshes")
    func add() async throws {
        let store = try makeStore()
        let model = TodayModel(store: store, date: "2026-06-22")
        await model.load()
        await model.add(entry("new", kcal: 120))
        #expect(model.entries.map(\.id) == ["new"])
        #expect(model.totals.calories == 120)
    }

    @Test("progress(for:) maps each macro total against its target")
    func progressForTargets() async throws {
        let store = try makeStore()
        try await store.add(entry("a", kcal: 1000, fat: 32.5, carbs: 125, protein: 50))
        let model = TodayModel(store: store, date: "2026-06-22")
        await model.load()

        let p = model.progress(for: MacroTargets(calories: 2000, fat: 65, carbs: 250, protein: 100))
        #expect(p.calories.fraction == 0.5)
        #expect(p.fat.fraction == 0.5)
        #expect(p.carbs.fraction == 0.5)
        #expect(p.protein.fraction == 0.5)
    }

    @Test("MacroProgress fraction clamps and flags over-target")
    func macroProgress() {
        #expect(MacroProgress(consumed: 1000, target: 2000).fraction == 0.5)
        #expect(MacroProgress(consumed: 2500, target: 2000).fraction == 1)   // clamped
        #expect(MacroProgress(consumed: 2500, target: 2000).isOver == true)
        #expect(MacroProgress(consumed: 2500, target: 2000).remaining == 0)
        #expect(MacroProgress(consumed: 500, target: 2000).remaining == 1500)
        #expect(MacroProgress(consumed: 10, target: 0).fraction == 0)        // no target
    }
}
