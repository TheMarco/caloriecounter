// CRUD + aggregation coverage for the SwiftData implementation of
// `NutritionStoring`. Each test gets a fresh in-memory `ModelContainer` so the
// suite runs on a dev/CI Mac with no simulator and no shared state.
//
// The query/aggregation expectations are pinned to the web semantics in
// `src/utils/idb.ts`: newest-first day listings (`getEntriesByDate`), inclusive
// string-compared range queries (`getEntriesInRange`), summed macros
// (`getMacroTotalsForDate`), oldest-first daily rows with offsets
// (`getDailyMacroTotalsWithOffset`), and frequency-then-recency food search
// (`searchPreviousFood` over `getAllUniqueFood`).

import Testing
import Foundation
@testable import NutritionStore
import NutritionCore

@Suite("SwiftDataStore")
struct SwiftDataStoreTests {

    // Fresh, isolated, in-memory store per test.
    private func makeStore() throws -> SwiftDataStore {
        try SwiftDataStore.make(inMemory: true)
    }

    // Build an entry with sensible defaults; override what a test cares about.
    // (Named `makeEntry` to avoid colliding with Darwin's C `struct entry`.)
    private func makeEntry(
        id: String = UUID().uuidString,
        date: String = "2026-06-22",
        ts: TimeInterval = 0,
        food: String = "Food",
        quantity: Double = 100,
        unit: String = "g",
        kcal: Double = 100,
        fat: Double = 1,
        carbs: Double = 2,
        protein: Double = 3,
        method: InputMethod = .text
    ) -> Entry {
        Entry(
            id: id, date: date, timestamp: Date(timeIntervalSince1970: ts),
            food: food, quantity: quantity, unit: unit,
            kcal: kcal, fat: fat, carbs: carbs, protein: protein, method: method
        )
    }

    // MARK: - add / fetch-by-date

    @Test("add then entries(on:) returns the entry round-tripped")
    func addAndFetchByDate() async throws {
        let store = try makeStore()
        let e = makeEntry(id: "e1", date: "2026-06-22", food: "Banana", kcal: 105, method: .barcode)
        try await store.add(e)

        let day = try await store.entries(on: "2026-06-22")
        #expect(day.count == 1)
        #expect(day.first == e)               // full Equatable round-trip
        #expect(day.first?.method == .barcode)
    }

    @Test("entries(on:) only returns the requested day")
    func fetchByDateFilters() async throws {
        let store = try makeStore()
        try await store.add(makeEntry(id: "a", date: "2026-06-21"))
        try await store.add(makeEntry(id: "b", date: "2026-06-22"))
        try await store.add(makeEntry(id: "c", date: "2026-06-22"))

        let day = try await store.entries(on: "2026-06-22")
        #expect(day.map(\.id).sorted() == ["b", "c"])
    }

    @Test("entries(on:) is newest-first by timestamp")
    func fetchByDateNewestFirst() async throws {
        let store = try makeStore()
        try await store.add(makeEntry(id: "old", date: "2026-06-22", ts: 100))
        try await store.add(makeEntry(id: "new", date: "2026-06-22", ts: 300))
        try await store.add(makeEntry(id: "mid", date: "2026-06-22", ts: 200))

        let day = try await store.entries(on: "2026-06-22")
        #expect(day.map(\.id) == ["new", "mid", "old"])
    }

    // MARK: - update / delete

    @Test("update mutates the stored entry in place")
    func updateInPlace() async throws {
        let store = try makeStore()
        try await store.add(makeEntry(id: "e1", food: "Apple", kcal: 95))
        var updated = makeEntry(id: "e1", food: "Green Apple", kcal: 80)
        updated.quantity = 2
        try await store.update(updated)

        let day = try await store.entries(on: "2026-06-22")
        #expect(day.count == 1)
        #expect(day.first?.food == "Green Apple")
        #expect(day.first?.kcal == 80)
        #expect(day.first?.quantity == 2)
    }

    @Test("delete removes the entry; deleting a missing id is a no-op")
    func deleteEntry() async throws {
        let store = try makeStore()
        try await store.add(makeEntry(id: "e1"))
        try await store.delete(id: "missing")          // no throw
        #expect(try await store.entries(on: "2026-06-22").count == 1)
        try await store.delete(id: "e1")
        #expect(try await store.entries(on: "2026-06-22").isEmpty)
    }

    // MARK: - .unique constraint

    @Test("adding a duplicate id does not create a second record")
    func uniqueIdUpsert() async throws {
        let store = try makeStore()
        try await store.add(makeEntry(id: "dupe", food: "First"))
        try await store.add(makeEntry(id: "dupe", food: "Second"))
        let day = try await store.entries(on: "2026-06-22")
        #expect(day.count == 1)
    }

    // MARK: - range query

    @Test("entries(from:to:) is an inclusive string-compared range")
    func rangeBoundaries() async throws {
        let store = try makeStore()
        try await store.add(makeEntry(id: "before", date: "2026-06-09"))
        try await store.add(makeEntry(id: "start", date: "2026-06-10"))
        try await store.add(makeEntry(id: "mid", date: "2026-06-15"))
        try await store.add(makeEntry(id: "end", date: "2026-06-20"))
        try await store.add(makeEntry(id: "after", date: "2026-06-21"))

        let inRange = try await store.entries(from: "2026-06-10", to: "2026-06-20")
        #expect(Set(inRange.map(\.id)) == ["start", "mid", "end"])
    }

    // MARK: - macro aggregation

    @Test("macroTotals(on:) sums kcal and macros over the day")
    func macroTotalsSums() async throws {
        let store = try makeStore()
        try await store.add(makeEntry(id: "a", date: "2026-06-22", kcal: 100, fat: 1, carbs: 2, protein: 3))
        try await store.add(makeEntry(id: "b", date: "2026-06-22", kcal: 250, fat: 4, carbs: 5, protein: 6))
        try await store.add(makeEntry(id: "other", date: "2026-06-21", kcal: 999))

        let totals = try await store.macroTotals(on: "2026-06-22")
        #expect(totals == MacroTotals(calories: 350, fat: 5, carbs: 7, protein: 9))
    }

    @Test("macroTotals(on:) is zero for an empty day")
    func macroTotalsEmpty() async throws {
        let store = try makeStore()
        #expect(try await store.macroTotals(on: "2026-06-22") == .zero)
    }

    // MARK: - offset upsert

    @Test("offset defaults to 0 and round-trips after setOffset")
    func offsetUpsert() async throws {
        let store = try makeStore()
        #expect(try await store.offset(on: "2026-06-22") == 0)
        try await store.setOffset(300, on: "2026-06-22")
        #expect(try await store.offset(on: "2026-06-22") == 300)
        // upsert: setting again replaces, never duplicates
        try await store.setOffset(450, on: "2026-06-22")
        #expect(try await store.offset(on: "2026-06-22") == 450)
    }

    // MARK: - dailyTotals

    @Test("dailyTotals(lastDays:) returns oldest-first rows with totals and offsets")
    func dailyTotalsWithOffset() async throws {
        let store = try makeStore()
        let today = LocalDate.today()
        let yesterday = LocalDate.lastDays(2).first!     // oldest of the 2-day window

        try await store.add(makeEntry(id: "t1", date: today, kcal: 200))
        try await store.add(makeEntry(id: "y1", date: yesterday, kcal: 500))
        try await store.setOffset(150, on: today)

        let rows = try await store.dailyTotals(lastDays: 2)
        #expect(rows.count == 2)
        #expect(rows.map(\.date) == [yesterday, today])   // oldest-first
        #expect(rows[0].totals.calories == 500)
        #expect(rows[0].offset == 0)
        #expect(rows[1].totals.calories == 200)
        #expect(rows[1].offset == 150)
        #expect(rows[1].netCalories == 50)                // 200 - 150
    }

    // MARK: - searchPreviousFoods

    @Test("searchPreviousFoods requires a 2+ char query")
    func searchMinLength() async throws {
        let store = try makeStore()
        try await store.add(makeEntry(id: "a", food: "Apple"))
        #expect(try await store.searchPreviousFoods("", limit: 15).isEmpty)
        #expect(try await store.searchPreviousFoods("a", limit: 15).isEmpty)
    }

    @Test("searchPreviousFoods dedupes by name and ranks by frequency then recency")
    func searchFrequencyThenRecency() async throws {
        let store = try makeStore()
        // "Chicken" eaten 3×, "Chickpeas" 2×, "Chicken Soup" 1×.
        try await store.add(makeEntry(id: "c1", ts: 10, food: "Chicken"))
        try await store.add(makeEntry(id: "c2", ts: 30, food: "chicken"))    // case-insensitive dupe
        try await store.add(makeEntry(id: "c3", ts: 20, food: "CHICKEN"))
        try await store.add(makeEntry(id: "p1", ts: 40, food: "Chickpeas"))
        try await store.add(makeEntry(id: "p2", ts: 5, food: "Chickpeas"))
        try await store.add(makeEntry(id: "s1", ts: 100, food: "Chicken Soup"))

        let results = try await store.searchPreviousFoods("chick", limit: 15)
        // Frequency: Chicken(3) > Chickpeas(2) > Chicken Soup(1). The representative
        // entry for the deduped "chicken" food is its most-recent occurrence (c2,
        // ts 30) — so its original casing ("chicken") is what surfaces, matching
        // web `getAllUniqueFood`.
        #expect(results.map(\.food) == ["chicken", "Chickpeas", "Chicken Soup"])
        #expect(results.first?.id == "c2")
    }

    // MARK: - on-disk persistence (the app's real make(url:) path)

    @Test("an on-disk store persists entries across actor instances")
    func onDiskPersistence() async throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("nutrition-test-\(UUID().uuidString).store")
        defer {
            for ext in ["", "-shm", "-wal"] {
                try? FileManager.default.removeItem(at: url.appendingPathExtension(ext.isEmpty ? "" : String(ext.dropFirst())))
            }
            try? FileManager.default.removeItem(at: url)
        }

        let writer = try SwiftDataStore.make(url: url)
        try await writer.add(makeEntry(id: "persisted", date: "2026-06-22", food: "Lentils"))

        // A fresh store actor over the same file must see the saved row.
        let reader = try SwiftDataStore.make(url: url)
        let day = try await reader.entries(on: "2026-06-22")
        #expect(day.map(\.id) == ["persisted"])
        #expect(day.first?.food == "Lentils")
    }

    @Test("schemaTypes lists both persistent models")
    func schemaTypesListed() {
        let names = SwiftDataStore.schemaTypes.map { String(describing: $0) }
        #expect(Set(names) == ["EntryRecord", "DayOffsetRecord", "WeightRecord"])
    }

    @Test("searchPreviousFoods breaks frequency ties by recency and honors the limit")
    func searchRecencyTieAndLimit() async throws {
        let store = try makeStore()
        // Two foods, each eaten once; the more recent should rank first.
        try await store.add(makeEntry(id: "old", ts: 10, food: "Berry Mix"))
        try await store.add(makeEntry(id: "new", ts: 99, food: "Berry Smoothie"))

        let ranked = try await store.searchPreviousFoods("berry", limit: 15)
        #expect(ranked.map(\.food) == ["Berry Smoothie", "Berry Mix"])

        let capped = try await store.searchPreviousFoods("berry", limit: 1)
        #expect(capped.map(\.food) == ["Berry Smoothie"])
    }

    @Test("deleteAll wipes every entry, offset, and weight; store stays usable")
    func deleteAllWipesEverything() async throws {
        let store = try makeStore()
        try await store.add(makeEntry(id: "a", date: "2026-06-21", food: "Oats"))
        try await store.add(makeEntry(id: "b", date: "2026-06-22", food: "Eggs"))
        try await store.setOffset(300, on: "2026-06-22")
        try await store.addWeight(WeightEntry(id: WeightEntry.id(for: "2026-06-22"), date: "2026-06-22",
                                              timestamp: Date(timeIntervalSince1970: 0), weightKg: 80))

        try await store.deleteAll()

        #expect(try await store.entries(from: "0000-01-01", to: "9999-12-31").isEmpty)
        #expect(try await store.offset(on: "2026-06-22") == 0)
        #expect(try await store.latestWeight() == nil)

        // The store remains usable afterwards.
        try await store.add(makeEntry(id: "c", date: "2026-06-23", food: "Apple"))
        #expect(try await store.entries(on: "2026-06-23").count == 1)
    }

    // MARK: - Body weight

    private func makeWeight(_ date: String, _ kg: Double, ts: TimeInterval = 0) -> WeightEntry {
        WeightEntry(id: WeightEntry.id(for: date), date: date, timestamp: Date(timeIntervalSince1970: ts), weightKg: kg)
    }

    @Test("weight upserts per day, lists oldest-first, and reports the latest")
    func weightCRUD() async throws {
        let store = try makeStore()
        try await store.addWeight(makeWeight("2026-06-10", 83.0))
        try await store.addWeight(makeWeight("2026-06-17", 82.4))
        try await store.addWeight(makeWeight("2026-06-23", 81.8))
        // Re-logging a day replaces, not duplicates.
        try await store.addWeight(makeWeight("2026-06-23", 81.5))

        let all = try await store.weights(from: "2026-06-01", to: "2026-06-30")
        #expect(all.map(\.date) == ["2026-06-10", "2026-06-17", "2026-06-23"])   // oldest-first, one per day
        #expect(all.last?.weightKg == 81.5)                                       // upserted
        #expect(try await store.latestWeight()?.date == "2026-06-23")

        // Range filtering.
        let recent = try await store.weights(from: "2026-06-15", to: "2026-06-30")
        #expect(recent.map(\.date) == ["2026-06-17", "2026-06-23"])
    }

    @Test("deleteWeight removes a single day's measurement")
    func weightDelete() async throws {
        let store = try makeStore()
        try await store.addWeight(makeWeight("2026-06-20", 80))
        try await store.addWeight(makeWeight("2026-06-21", 79.5))
        try await store.deleteWeight(id: WeightEntry.id(for: "2026-06-20"))

        let all = try await store.weights(from: "2026-06-01", to: "2026-06-30")
        #expect(all.map(\.date) == ["2026-06-21"])
        #expect(try await store.latestWeight()?.weightKg == 79.5)
    }

    // MARK: - Fiber / sodium / sugar + confidence

    @Test("fiber/sodium/sugar + confidence round-trip; nil stays nil, 0 stays 0")
    func nutrientFieldsRoundTrip() async throws {
        let store = try makeStore()
        let entry = Entry(id: "n1", date: "2026-06-23", timestamp: Date(timeIntervalSince1970: 0),
                          food: "Lentils", quantity: 1, unit: "bowl", kcal: 230, fat: 1, carbs: 40, protein: 18,
                          method: .barcode, fiber: 15, sodium: 0, sugar: nil, nutritionConfidence: .barcode)
        try await store.add(entry)

        let got = try await store.entries(on: "2026-06-23").first
        #expect(got?.fiber == 15)
        #expect(got?.sodium == 0)      // a KNOWN zero stays zero
        #expect(got?.sugar == nil)     // UNKNOWN stays nil — not coerced to 0
        #expect(got?.nutritionConfidence == .barcode)
        #expect(got == entry)          // full Equatable round-trip

        // A plain entry leaves all new fields nil.
        try await store.add(Entry(id: "n2", date: "2026-06-23", timestamp: Date(timeIntervalSince1970: 1),
                                  food: "Plain", quantity: 1, unit: "g", kcal: 50, fat: 0, carbs: 0, protein: 0, method: .text))
        let plain = try await store.entries(on: "2026-06-23").first { $0.id == "n2" }
        #expect(plain?.fiber == nil && plain?.sodium == nil && plain?.nutritionConfidence == nil)
    }
}
