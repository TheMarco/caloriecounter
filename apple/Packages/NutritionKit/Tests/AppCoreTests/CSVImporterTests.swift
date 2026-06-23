// CSVImporter: per-entry round-trip (with comma-escaped names), legacy daily-totals
// compatibility, format detection, and store-apply.

import Testing
import Foundation
@testable import AppCore
import NutritionCore
import NutritionStore

@Suite("CSVImporter")
struct CSVImporterTests {

    private func entry(_ id: String, _ food: String, kcal: Double, fat: Double, carbs: Double, protein: Double,
                       unit: String = "plate", method: InputMethod = .text, date: String = "2026-06-22") -> Entry {
        Entry(id: id, date: date, timestamp: Date(timeIntervalSince1970: 1_750_000_000),
              food: food, quantity: 1, unit: unit, kcal: kcal, fat: fat, carbs: carbs, protein: protein, method: method)
    }

    @Test("per-entry export round-trips every food, including names with commas")
    func perEntryRoundTrip() throws {
        let entries = [
            entry("a", "Salmon, Rice & Greens", kcal: 560, fat: 22, carbs: 50, protein: 38, method: .text),
            entry("b", "Almonds", kcal: 174, fat: 15, carbs: 6, protein: 6, unit: "g", method: .label),
        ]
        let csv = CSVExporter.entriesCSV(entries: entries, offsets: ["2026-06-22": 300])
        let result = try CSVImporter.parse(csv)

        #expect(result.entries.count == 2)
        let salmon = try #require(result.entries.first { $0.food.hasPrefix("Salmon") })
        #expect(salmon.food == "Salmon, Rice & Greens")   // comma survived escaping
        #expect(salmon.kcal == 560)
        #expect(salmon.carbs == 50)
        #expect(salmon.method == .text)
        let almonds = try #require(result.entries.first { $0.food == "Almonds" })
        #expect(almonds.unit == "g")
        #expect(almonds.method == .label)
        #expect(result.offsets["2026-06-22"] == 300)
    }

    @Test("legacy daily-totals CSV still imports (as one row per day)")
    func legacyDailyCompat() throws {
        let csv = """
        date,calories_consumed,calories_burned,net_calories,carbs,fat,protein
        2026-06-21,1800,200,1600,210.0,60.0,95.0
        2026-06-22,2000,0,2000,250.0,65.0,100.0
        """
        let result = try CSVImporter.parse(csv)
        #expect(result.entries.count == 2)
        let day = try #require(result.entries.first { $0.date == "2026-06-22" })
        #expect(day.food == "Imported daily total")
        #expect(day.kcal == 2000)
        #expect(day.carbs == 250)
        #expect(result.offsets["2026-06-21"] == 200)
        #expect(result.offsets["2026-06-22"] == nil)   // 0 burned → no offset
    }

    @Test("an unrecognized header is rejected")
    func rejectsBadHeader() {
        #expect(throws: CSVImporter.ImportError.unrecognizedFormat) {
            _ = try CSVImporter.parse("name,age\nbob,30")
        }
    }

    @Test("a header with no data rows throws noRows")
    func noRows() {
        #expect(throws: CSVImporter.ImportError.noRows) {
            _ = try CSVImporter.parse(CSVExporter.entryHeader + "\n")
        }
    }

    @Test("apply writes every entry and offset; re-import replaces, not duplicates")
    func apply() async throws {
        let store = try SwiftDataStore.make(inMemory: true)
        let entries = [
            entry("a", "Oatmeal", kcal: 310, fat: 6, carbs: 54, protein: 10, unit: "bowl"),
            entry("b", "Chicken Salad", kcal: 420, fat: 18, carbs: 22, protein: 40, unit: "bowl", method: .voice),
        ]
        let csv = CSVExporter.entriesCSV(entries: entries, offsets: ["2026-06-22": 250])
        let result = try CSVImporter.parse(csv)

        let count = await CSVImporter.apply(result, to: store)
        #expect(count == 1)   // one day
        let day = try await store.entries(on: "2026-06-22")
        #expect(Set(day.map(\.food)) == ["Oatmeal", "Chicken Salad"])
        #expect(try await store.offset(on: "2026-06-22") == 250)

        // Re-import is idempotent (deterministic ids).
        _ = await CSVImporter.apply(result, to: store)
        #expect(try await store.entries(on: "2026-06-22").count == 2)
    }
}
