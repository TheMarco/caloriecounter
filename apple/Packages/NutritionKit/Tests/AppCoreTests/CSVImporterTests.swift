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

    @Test("weigh-ins export and import alongside foods (backup round-trips weight)")
    func weightRoundTrip() throws {
        let entries = [entry("a", "Apple", kcal: 95, fat: 0, carbs: 25, protein: 0, method: .barcode, date: "2026-06-21")]
        let weights = [
            WeightEntry(id: WeightEntry.id(for: "2026-06-20"), date: "2026-06-20",
                        timestamp: Date(timeIntervalSince1970: 1_750_000_000), weightKg: 82.4),
            WeightEntry(id: WeightEntry.id(for: "2026-06-22"), date: "2026-06-22",
                        timestamp: Date(timeIntervalSince1970: 1_750_200_000), weightKg: 81.9),
        ]
        let csv = CSVExporter.entriesCSV(entries: entries, offsets: [:], weights: weights)
        let result = try CSVImporter.parse(csv)

        #expect(result.entries.count == 1)
        #expect(result.weights.count == 2)
        let w = try #require(result.weights.first { $0.date == "2026-06-20" })
        #expect(w.weightKg == 82.4)
        #expect(result.dayCount == 3)   // apple day + 2 weigh-in days
    }

    @Test("fiber/sodium/sugar export+import; blanks stay nil; old 10-col files still load")
    func nutrientColumns() throws {
        let e = Entry(id: "x", date: "2026-06-22", timestamp: Date(timeIntervalSince1970: 1_750_000_000),
                      food: "Bran Cereal", quantity: 1, unit: "bowl", kcal: 200, fat: 2, carbs: 44, protein: 6,
                      method: .label, fiber: 12, sodium: 210, sugar: nil)
        let csv = CSVExporter.entriesCSV(entries: [e], offsets: [:])
        let header = csv.split(whereSeparator: \.isNewline).first.map(String.init) ?? ""
        #expect(header.hasSuffix("fiber,sodium,sugar,method"))

        let got = try #require(CSVImporter.parse(csv).entries.first)
        #expect(got.fiber == 12)
        #expect(got.sodium == 210)   // milligrams
        #expect(got.sugar == nil)    // blank cell → nil, not 0

        // Old 10-column file (no fiber/sodium/sugar columns) still imports cleanly.
        let old = """
        date,time,food,quantity,unit,calories,fat,carbs,protein,method
        2026-06-22,08:00,Oatmeal,1,bowl,310,6.0,54.0,10.0,text
        """
        let oldGot = try #require(CSVImporter.parse(old).entries.first)
        #expect(oldGot.food == "Oatmeal")
        #expect(oldGot.fiber == nil && oldGot.sodium == nil && oldGot.sugar == nil)
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

    @Test("imported per-entry data surfaces in the 90-day history window")
    func importedDataAppearsInDailyTotals() async throws {
        let store = try SwiftDataStore.make(inMemory: true)
        let cal = Calendar.current
        func key(daysAgo: Int) -> String {
            LocalDate.key(for: cal.date(byAdding: .day, value: -daysAgo, to: Date())!)
        }
        let today = key(daysAgo: 0), mid = key(daysAgo: 45)
        func mk(_ id: String, _ date: String, _ food: String) -> Entry {
            Entry(id: id, date: date, timestamp: Date(timeIntervalSince1970: 0), food: food,
                  quantity: 1, unit: "bowl", kcal: 310, fat: 6, carbs: 54, protein: 10, method: .text)
        }
        let csv = CSVExporter.entriesCSV(entries: [mk("a", today, "Oatmeal"), mk("b", mid, "Salmon, Rice")],
                                         offsets: [today: 300])
        let result = try CSVImporter.parse(csv)
        _ = await CSVImporter.apply(result, to: store)

        let days = try await store.dailyTotals(lastDays: 90)
        let withFood = days.filter { $0.totals.calories > 0 }
        #expect(withFood.count == 2)                                     // both days land in-window
        #expect(days.contains { $0.date == today && $0.offset == 300 })  // offset applied
    }
}
