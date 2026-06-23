// Domain value types: Codable round-trips, enum metadata, and the
// ParsedFood→Entry / MacroTotals aggregation glue ported from the web.

import Testing
import Foundation
@testable import NutritionCore

@Suite("Domain models")
struct DomainModelTests {

    // MARK: - Fixtures

    private func sampleEntry(
        id: String = "e1",
        date: String = "2026-06-22",
        food: String = "Grilled Chicken Breast",
        quantity: Double = 150,
        unit: String = "g",
        kcal: Double = 248,
        fat: Double = 5.4,
        carbs: Double = 0,
        protein: Double = 46.2,
        method: InputMethod = .text,
        confidence: Double? = 0.9
    ) -> Entry {
        Entry(
            id: id, date: date, timestamp: Date(timeIntervalSince1970: 1_750_000_000),
            food: food, quantity: quantity, unit: unit,
            kcal: kcal, fat: fat, carbs: carbs, protein: protein,
            method: method, confidence: confidence
        )
    }

    // MARK: - Codable round-trips

    @Test("Entry encodes and decodes without loss")
    func entryCodableRoundTrip() throws {
        let entry = sampleEntry()
        let data = try JSONEncoder().encode(entry)
        let decoded = try JSONDecoder().decode(Entry.self, from: data)
        #expect(decoded == entry)
    }

    @Test("Entry with nil confidence round-trips")
    func entryNilConfidenceRoundTrip() throws {
        let entry = sampleEntry(confidence: nil)
        let decoded = try JSONDecoder().decode(Entry.self, from: JSONEncoder().encode(entry))
        #expect(decoded == entry)
        #expect(decoded.confidence == nil)
    }

    @Test("AppSettings round-trips and defaults match the web app")
    func appSettingsCodableAndDefaults() throws {
        #expect(AppSettings.default.units == .metric)
        #expect(AppSettings.default.targets == .default)

        let settings = AppSettings(
            targets: MacroTargets(calories: 1800, fat: 60, carbs: 200, protein: 120),
            units: .imperial
        )
        let decoded = try JSONDecoder().decode(AppSettings.self, from: JSONEncoder().encode(settings))
        #expect(decoded == settings)
    }

    @Test("ParsedFood round-trips with optional fields")
    func parsedFoodCodableRoundTrip() throws {
        let parsed = ParsedFood(
            food: "Banana", quantity: 1, unit: "piece",
            kcal: 105, fat: 0.4, carbs: 27, protein: 1.3,
            confidence: 0.8, notes: "medium"
        )
        let decoded = try JSONDecoder().decode(ParsedFood.self, from: JSONEncoder().encode(parsed))
        #expect(decoded == parsed)
    }

    @Test("PhotoDetails default matches the web pickers (medium / home)")
    func photoDetailsDefault() {
        #expect(PhotoDetails.default.plateSize == .medium)
        #expect(PhotoDetails.default.servingType == .home)
        #expect(PhotoDetails.default.additionalDetails.isEmpty)
    }

    // MARK: - Enum raw values & metadata

    @Test("InputMethod raw values cover the web union plus the on-device label scan")
    func inputMethodRawValues() {
        // The first four mirror the web union 'barcode'|'voice'|'text'|'photo';
        // 'label' is an iOS-only addition (on-device nutrition-label OCR).
        #expect(InputMethod.allCases.map(\.rawValue) == ["barcode", "voice", "text", "photo", "label"])
        #expect(InputMethod.text.label == "Text")
        #expect(InputMethod.barcode.detail == "Scan product barcode")
        #expect(InputMethod.label.detail == "Scan a nutrition label")
    }

    @Test("Hyphenated portion enums keep web-compatible raw values")
    func portionEnumRawValues() {
        #expect(PlateSize.extraLarge.rawValue == "extra-large")
        #expect(ServingType.fastFood.rawValue == "fast-food")
        // Prompt phrases drive the cloud parser — keep them stable.
        #expect(PlateSize.medium.promptDescription.contains("9-10 inches"))
        #expect(ServingType.restaurant.promptDescription.contains("larger portions"))
    }

    // MARK: - Aggregation & conversion glue

    @Test("MacroTotals.summing reduces like getMacroTotalsForDate")
    func macroTotalsSumming() {
        let entries = [
            sampleEntry(id: "a", kcal: 248, fat: 5.4, carbs: 0, protein: 46.2),
            sampleEntry(id: "b", kcal: 111, fat: 0.9, carbs: 23, protein: 2.6),
        ]
        let totals = MacroTotals.summing(entries)
        #expect(totals.calories == 359)
        #expect(abs(totals.fat - 6.3) < 1e-9)
        #expect(totals.carbs == 23)
        #expect(abs(totals.protein - 48.8) < 1e-9)
    }

    @Test("MacroTotals.summing of no entries is zero")
    func macroTotalsEmpty() {
        #expect(MacroTotals.summing([]) == .zero)
    }

    @Test("ParsedFood.makeEntry carries nutrition over and stamps identity")
    func parsedFoodMakeEntry() {
        let parsed = ParsedFood(
            food: "Greek Yogurt", quantity: 150, unit: "g",
            kcal: 100, fat: 0.4, carbs: 6, protein: 17, confidence: 0.7
        )
        let ts = Date(timeIntervalSince1970: 1_750_000_500)
        let entry = parsed.makeEntry(id: "x1", date: "2026-06-22", timestamp: ts, method: .voice)
        #expect(entry.id == "x1")
        #expect(entry.date == "2026-06-22")
        #expect(entry.timestamp == ts)
        #expect(entry.method == .voice)
        #expect(entry.food == "Greek Yogurt")
        #expect(entry.kcal == 100)
        #expect(entry.protein == 17)
        #expect(entry.confidence == 0.7)
    }

    @Test("DayTotals.netCalories floors consumed minus offset at zero")
    func dayTotalsNetCalories() {
        let totals = MacroTotals(calories: 2000, fat: 60, carbs: 200, protein: 100)
        #expect(DayTotals(date: "2026-06-22", totals: totals, offset: 500).netCalories == 1500)
        #expect(DayTotals(date: "2026-06-22", totals: totals, offset: 2500).netCalories == 0)
    }

    @Test("ParsedFood carries fiber/sodium/sugar + confidence into Entry and back")
    func parsedFoodNutrients() {
        let p = ParsedFood(food: "X", quantity: 1, unit: "g", kcal: 100,
                           fiber: 3, sodium: 850, sugar: nil, nutritionConfidence: .estimated)
        let e = p.makeEntry(id: "e", date: "2026-06-23", timestamp: Date(timeIntervalSince1970: 0), method: .text)
        #expect(e.fiber == 3)
        #expect(e.sodium == 850)
        #expect(e.sugar == nil)
        #expect(e.nutritionConfidence == .estimated)

        let back = ParsedFood(entry: e)   // round-trip back out
        #expect(back.fiber == 3 && back.sodium == 850 && back.sugar == nil)
        #expect(back.nutritionConfidence == .estimated)
    }

    @Test("NutritionConfidence.isExact distinguishes measured sources from estimates")
    func confidenceIsExact() {
        #expect(NutritionConfidence.label.isExact)
        #expect(NutritionConfidence.barcode.isExact)
        #expect(NutritionConfidence.userEdited.isExact)
        #expect(!NutritionConfidence.estimated.isExact)
        #expect(!NutritionConfidence.unknown.isExact)
    }
}
