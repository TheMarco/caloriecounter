// CSVExporter fidelity to the web `csvExport.ts`.

import Testing
@testable import AppCore
import NutritionCore

@Suite("CSVExporter")
struct CSVExporterTests {

    private func day(_ date: String, cal: Double = 0, fat: Double = 0, carbs: Double = 0, protein: Double = 0, offset: Double = 0) -> DayTotals {
        DayTotals(date: date, totals: MacroTotals(calories: cal, fat: fat, carbs: carbs, protein: protein), offset: offset)
    }

    @Test("header matches the web export exactly")
    func header() {
        #expect(CSVExporter.header == "date,calories_consumed,calories_burned,net_calories,carbs,fat,protein")
    }

    @Test("rows format calories/offset as integers and macros to one decimal")
    func rowFormat() {
        let csv = CSVExporter.csv(from: [day("2026-06-22", cal: 2000, fat: 65.4, carbs: 250.25, protein: 100, offset: 300)])
        let lines = csv.split(separator: "\n")
        #expect(lines.count == 2)
        // net = max(0, 2000 - 300) = 1700; carbs 250.25 → 250.2 (rounded to 1dp)
        #expect(lines[1] == "2026-06-22,2000,300,1700,250.2,65.4,100.0")
    }

    @Test("net calories clamp at zero when the offset exceeds intake")
    func netClamp() {
        let csv = CSVExporter.csv(from: [day("2026-06-22", cal: 200, offset: 500)])
        #expect(csv.split(separator: "\n")[1] == "2026-06-22,200,500,0,0.0,0.0,0.0")
    }

    @Test("days with no food and no offset are filtered out")
    func filtersEmptyDays() {
        let csv = CSVExporter.csv(from: [
            day("2026-06-20"),                       // empty → dropped
            day("2026-06-21", offset: 250),          // offset only → kept
            day("2026-06-22", cal: 500),             // food → kept
        ])
        let lines = csv.split(separator: "\n")
        #expect(lines.count == 3)                    // header + 2 rows
        #expect(lines[1].hasPrefix("2026-06-21"))
        #expect(lines[2].hasPrefix("2026-06-22"))
    }

    @Test("filename carries the date")
    func filename() {
        #expect(CSVExporter.filename(today: "2026-06-22") == "calorie-tracker-data-2026-06-22.csv")
    }

    @Test("an all-empty dataset yields just the header")
    func emptyDataset() {
        #expect(CSVExporter.csv(from: []) == CSVExporter.header)
    }
}
