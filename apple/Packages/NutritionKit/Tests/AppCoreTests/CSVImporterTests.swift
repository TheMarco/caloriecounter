// CSVImporter: parsing, round-trip against CSVExporter, and store-apply.

import Testing
import Foundation
@testable import AppCore
import NutritionCore
import NutritionStore

@Suite("CSVImporter")
struct CSVImporterTests {

    @Test("parses a well-formed export into per-day rows")
    func parses() throws {
        let csv = """
        date,calories_consumed,calories_burned,net_calories,carbs,fat,protein
        2026-06-21,1800,200,1600,210.5,60.0,95.0
        2026-06-22,2000,0,2000,250.0,65.0,100.0
        """
        let days = try CSVImporter.parse(csv)
        #expect(days.count == 2)
        #expect(days[0] == ImportedDay(date: "2026-06-21", calories: 1800, carbs: 210.5, fat: 60, protein: 95, offset: 200))
        #expect(days[1].date == "2026-06-22")
        #expect(days[1].offset == 0)
    }

    @Test("rejects a file that isn't a CalorieCounter export")
    func rejectsBadHeader() {
        #expect(throws: CSVImporter.ImportError.missingHeader) {
            _ = try CSVImporter.parse("name,age\nbob,30")
        }
    }

    @Test("a header with no data rows throws noRows")
    func noRows() {
        #expect(throws: CSVImporter.ImportError.noRows) {
            _ = try CSVImporter.parse("date,calories_consumed,calories_burned,net_calories,carbs,fat,protein\n")
        }
    }

    @Test("round-trips the exporter's output (to 1-decimal macro precision)")
    func roundTrip() throws {
        let source = [
            DayTotals(date: "2026-06-20", totals: MacroTotals(calories: 1500, fat: 40, carbs: 180, protein: 70), offset: 250),
            DayTotals(date: "2026-06-22", totals: MacroTotals(calories: 2200, fat: 70, carbs: 260, protein: 120), offset: 0),
        ]
        let csv = CSVExporter.csv(from: source)
        let parsed = try CSVImporter.parse(csv)
        #expect(parsed.count == 2)
        #expect(parsed[0] == ImportedDay(date: "2026-06-20", calories: 1500, carbs: 180, fat: 40, protein: 70, offset: 250))
        #expect(parsed[1].calories == 2200)
    }

    @Test("apply writes one daily-total entry per day plus its offset")
    func apply() async throws {
        let store = try SwiftDataStore.make(inMemory: true)
        let days = [
            ImportedDay(date: "2026-06-21", calories: 1800, carbs: 210, fat: 60, protein: 95, offset: 200),
            ImportedDay(date: "2026-06-22", calories: 2000, carbs: 250, fat: 65, protein: 100, offset: 0),
        ]
        let count = await CSVImporter.apply(days, to: store)
        #expect(count == 2)

        let day21 = try await store.entries(on: "2026-06-21")
        #expect(day21.count == 1)
        #expect(day21.first?.kcal == 1800)
        #expect(day21.first?.food == "Imported daily total")
        #expect(try await store.offset(on: "2026-06-21") == 200)
        #expect(try await store.macroTotals(on: "2026-06-22") == MacroTotals(calories: 2000, fat: 65, carbs: 250, protein: 100))

        // Re-importing the same data replaces, doesn't duplicate (deterministic id).
        _ = await CSVImporter.apply(days, to: store)
        #expect(try await store.entries(on: "2026-06-21").count == 1)
    }
}
