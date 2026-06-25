// FoodConfirmModel (the shared convergence point of all four capture flows) and
// TextInputModel, driven by an in-memory store and a stub parser — no UI.

import Testing
import Foundation
@testable import AppCore
import NutritionCore
import NutritionStore

private struct StubParser: FoodParsing {
    let result: ParsedFood
    func parse(text: String, units: UnitSystem) async throws -> ParsedFood { result }
}

@MainActor
@Suite("FoodConfirmModel")
struct FoodConfirmModelTests {

    private func makeStore() throws -> SwiftDataStore { try SwiftDataStore.make(inMemory: true) }

    private let parsed = ParsedFood(food: "Brown Rice", quantity: 100, unit: "g",
                                    kcal: 111, fat: 0.9, carbs: 23, protein: 2.6)

    @Test("context nutrients are read-only, derived from the parse, and scale with quantity; nil stays nil")
    func contextNutrientsDerived() throws {
        let parsed = ParsedFood(food: "Bran", quantity: 1, unit: "bowl", kcal: 200,
                                fiber: 12, sodium: 210, sugar: nil, nutritionConfidence: .barcode)
        let model = FoodConfirmModel(parsed: parsed, method: .barcode, store: try makeStore())
        // Derived from the parse at the original quantity; unknown stays unknown.
        #expect(model.fiber == 12)
        #expect(model.sodium == 210)
        #expect(model.sugar == nil)
        #expect(model.makeEntry().nutritionConfidence == .barcode)   // not hand-edited

        // Doubling the quantity scales them like the macros do.
        model.quantityText = "2"
        #expect(model.fiber == 24)
        #expect(model.sodium == 420)
        #expect(model.sugar == nil)
    }

    @Test("nutrition scales (and rounds kcal) the moment the quantity changes")
    func derivedScaling() throws {
        let model = FoodConfirmModel(parsed: parsed, method: .text, store: try makeStore())
        // Starts at the parsed 100 g.
        #expect(model.kcal == 111)
        // Changing the quantity text alone updates the derived nutrition — no
        // explicit recalc step (this is what was broken in the barcode flow).
        model.quantityText = "200"
        #expect(model.kcal == 222)                 // round(1.11 × 200)
        #expect(abs(model.fat - 1.8) < 1e-9)
        #expect(abs(model.carbs - 46) < 1e-9)
        #expect(abs(model.protein - 5.2) < 1e-9)
    }

    @Test("changing to a compatible unit recomputes calories for that much")
    func compatibleUnitChangeRecomputes() throws {
        // 1 oz of bread = 70 kcal; the amount NUMBER stays, the unit reinterprets.
        let bread = ParsedFood(food: "Bread", quantity: 1, unit: "oz", kcal: 70, fat: 1, carbs: 14, protein: 3)
        let model = FoodConfirmModel(parsed: bread, method: .barcode, store: try makeStore())
        #expect(model.kcal == 70)
        model.unit = "lb"             // keep "1", now 1 lb = 16 oz
        #expect(model.kcal == 1120)   // 70 × 16
    }

    @Test("an incompatible unit change relabels (nutrition follows the number only)")
    func incompatibleUnitChangeRelabels() throws {
        let bread = ParsedFood(food: "Bread", quantity: 1, unit: "serving", kcal: 110)
        let model = FoodConfirmModel(parsed: bread, method: .barcode, store: try makeStore())
        model.unit = "slice"          // serving↔slice has no conversion → relabel
        #expect(model.kcal == 110)    // 1 slice == 1 serving == 110
    }

    @Test("zero quantity zeroes everything")
    func zeroQuantity() throws {
        let model = FoodConfirmModel(parsed: parsed, method: .text, store: try makeStore())
        model.quantityText = "0"
        #expect(model.kcal == 0 && model.fat == 0 && model.carbs == 0 && model.protein == 0)
    }

    @Test("a breakdown drives the totals; editing/removing a component updates them and marks user-edited")
    func breakdownDrivesTotals() throws {
        let parsed = ParsedFood(food: "BLT", quantity: 1, unit: "serving", kcal: 240, fat: 9, carbs: 30, protein: 11,
                                nutritionConfidence: .estimated,
                                components: [
                                    FoodComponent(name: "Bacon", grams: 16, kcal: 80, fat: 7, carbs: 0, protein: 5, sodium: 200),
                                    FoodComponent(name: "Bread", grams: 60, kcal: 160, fat: 2, carbs: 30, protein: 6, fiber: 2, sodium: 300),
                                ])
        let model = FoodConfirmModel(parsed: parsed, method: .text, store: try makeStore())
        #expect(model.hasBreakdown)
        #expect(model.kcal == 240)                 // Σ components, not the (stale) top-line
        #expect(model.protein == 11)
        #expect(model.sodium == 500)
        #expect(model.makeEntry().nutritionConfidence == .estimated)   // untouched → keeps the source

        // Double the bacon (16 → 32 g): its 80 kcal doubles, total 240 → 320.
        model.setComponentGrams(at: 0, to: 32)
        #expect(model.kcal == 320)
        #expect(model.makeEntry().nutritionConfidence == .userEdited)

        // Remove the bacon ("no bacon"): total drops to the bread alone.
        model.removeComponent(at: 0)
        #expect(model.kcal == 160)
        #expect(model.components.count == 1)
    }

    @Test("changing the serving count scales a breakdown's total")
    func breakdownScalesWithServings() throws {
        let parsed = ParsedFood(food: "BLT", quantity: 1, unit: "serving", kcal: 240,
                                components: [FoodComponent(name: "Bacon", grams: 16, kcal: 80, fat: 7, carbs: 0, protein: 5),
                                             FoodComponent(name: "Bread", grams: 60, kcal: 160, fat: 2, carbs: 30, protein: 6)])
        let model = FoodConfirmModel(parsed: parsed, method: .text, store: try makeStore())
        #expect(model.kcal == 240)
        model.quantityText = "2"
        #expect(model.kcal == 480)                 // two servings
    }

    @Test("no breakdown → nutrition (incl. fiber/sodium) all scales from the parse with the quantity")
    func noBreakdownScalesFromParse() throws {
        let p = ParsedFood(food: "Brown Rice", quantity: 100, unit: "g", kcal: 111, fat: 0.9, carbs: 23, protein: 2.6, fiber: 1)
        let model = FoodConfirmModel(parsed: p, method: .text, store: try makeStore())
        #expect(!model.hasBreakdown)
        #expect(model.kcal == 111)
        #expect(model.fiber == 1)
        model.quantityText = "200"
        #expect(model.kcal == 222)                 // scales from the parse
        #expect(model.fiber == 2)                  // fiber is a nutrient too — scales with the amount
    }

    @Test("save persists an Entry with the edited values and chosen method")
    func savePersists() async throws {
        let store = try makeStore()
        let model = FoodConfirmModel(parsed: parsed, method: .barcode, store: store)
        model.food = "  Basmati Rice  "
        model.quantityText = "150"
        let saved = await model.save(date: "2026-06-22", now: Date(timeIntervalSince1970: 0))

        #expect(saved.food == "Basmati Rice")     // trimmed
        #expect(saved.quantity == 150)
        #expect(saved.method == .barcode)
        let day = try await store.entries(on: "2026-06-22")
        #expect(day.map(\.id) == [saved.id])
    }

    // MARK: - Confirm-screen correction chips (½ · 2× · Less · More · Swap unit)

    @Test("Less / More nudge the amount ~15% and re-round; calories follow")
    func nudgeAdjustsAmount() throws {
        let model = FoodConfirmModel(parsed: parsed, method: .text, store: try makeStore())
        #expect(model.quantity == 100)
        model.nudge(1.15)                       // More
        #expect(model.quantity == 115)          // tidy-rounded
        #expect(model.kcal == 128)              // round(1.11 × 115)

        model.quantityText = "100"
        model.nudge(0.85)                       // Less
        #expect(model.quantity == 85)
        #expect(model.kcal == 94)               // round(1.11 × 85)
    }

    @Test("½ and 2× scale from the original serving, not the current amount")
    func portionChips() throws {
        let model = FoodConfirmModel(parsed: parsed, method: .text, store: try makeStore())
        model.setPortion(2)
        #expect(model.quantity == 200)
        #expect(model.isPortion(2))
        model.setPortion(0.5)
        #expect(model.quantity == 50)           // half of the BASE 100, not half of 200
        #expect(model.isPortion(0.5))
    }

    @Test("Swap unit cycles compatible units preserving nutrition; a no-op when only one")
    func cycleUnitPreservesNutrition() throws {
        let model = FoodConfirmModel(parsed: parsed, method: .text, store: try makeStore())
        #expect(model.unit == "g")
        let before = model.kcal                 // 111 at 100 g
        model.cycleUnit()                       // g → oz
        #expect(model.unit == "oz")
        #expect(abs(model.kcal - before) <= 2)  // nutrition preserved across the swap

        // Abstract units (piece/slice/…) have no family → cycleUnit does nothing.
        let piece = FoodConfirmModel(parsed: ParsedFood(food: "Egg", quantity: 1, unit: "piece", kcal: 78),
                                     method: .text, store: try makeStore())
        piece.cycleUnit()
        #expect(piece.unit == "piece")
        #expect(piece.quantity == 1)
    }

    @Test("the confirm badge confidence reflects provenance and flips to Adjusted on edit")
    func confidenceExposed() throws {
        let est = FoodConfirmModel(
            parsed: ParsedFood(food: "Soup", quantity: 1, unit: "bowl", kcal: 200, nutritionConfidence: .estimated),
            method: .text, store: try makeStore())
        #expect(est.nutritionConfidence == .estimated)
        #expect(!est.isExact)

        let bar = FoodConfirmModel(
            parsed: ParsedFood(food: "Bar", quantity: 1, unit: "piece", kcal: 200, nutritionConfidence: .barcode),
            method: .barcode, store: try makeStore())
        #expect(bar.nutritionConfidence == .barcode)
        #expect(bar.isExact)

        // Editing the breakdown flips to userEdited (Adjusted).
        let blt = FoodConfirmModel(
            parsed: ParsedFood(food: "BLT", quantity: 1, unit: "serving", kcal: 240, nutritionConfidence: .estimated,
                               components: [FoodComponent(name: "Bacon", grams: 16, kcal: 80, fat: 7, carbs: 0, protein: 5)]),
            method: .text, store: try makeStore())
        #expect(blt.nutritionConfidence == .estimated)
        blt.setComponentGrams(at: 0, to: 32)
        #expect(blt.nutritionConfidence == .userEdited)
        #expect(blt.isExact)
    }

    // MARK: - Per-food correction memory

    @Test("an estimated parse pre-applies a remembered correction and becomes Adjusted")
    func preAppliesRememberedCorrection() async throws {
        let corrections = MockCorrectionStore([
            FoodCorrection(food: "Banana", unit: "piece", kcal: 100, fat: 0.4, carbs: 27, protein: 1.3,
                           updatedAt: Date(timeIntervalSince1970: 1))
        ])
        let parsed = ParsedFood(food: "banana", quantity: 1, unit: "piece", kcal: 130, nutritionConfidence: .estimated)
        let model = FoodConfirmModel(parsed: parsed, method: .text, store: try makeStore(), corrections: corrections)
        await model.loadRememberedCorrection()
        #expect(model.kcal == 100)                      // pre-applied (was a 130 estimate)
        #expect(model.nutritionConfidence == .userEdited)
        #expect(model.appliedRememberedCorrection)
        // …and it still scales with quantity (per-unit basis).
        model.quantityText = "2"
        #expect(model.kcal == 200)
    }

    @Test("a measured (barcode) parse is NOT overwritten by a correction")
    func measuredParseNotOverwritten() async throws {
        let corrections = MockCorrectionStore([
            FoodCorrection(food: "Bar", unit: "piece", kcal: 50, fat: 1, carbs: 5, protein: 5,
                           updatedAt: Date(timeIntervalSince1970: 1))
        ])
        let parsed = ParsedFood(food: "Bar", quantity: 1, unit: "piece", kcal: 210, nutritionConfidence: .barcode)
        let model = FoodConfirmModel(parsed: parsed, method: .barcode, store: try makeStore(), corrections: corrections)
        await model.loadRememberedCorrection()
        #expect(model.kcal == 210)                      // barcode is trusted
        #expect(model.nutritionConfidence == .barcode)
        #expect(!model.appliedRememberedCorrection)
    }

    @Test("editing the numbers and saving remembers a per-unit correction")
    func savingRemembersCorrection() async throws {
        let corrections = MockCorrectionStore()
        let parsed = ParsedFood(food: "BLT", quantity: 1, unit: "serving", kcal: 240, nutritionConfidence: .estimated,
                                components: [FoodComponent(name: "Bacon", grams: 16, kcal: 80, fat: 7, carbs: 0, protein: 5),
                                             FoodComponent(name: "Bread", grams: 60, kcal: 160, fat: 2, carbs: 30, protein: 6)])
        let model = FoodConfirmModel(parsed: parsed, method: .text, store: try makeStore(), corrections: corrections)
        model.setComponentGrams(at: 0, to: 32)          // edit → 320 kcal, user-edited
        _ = await model.save(date: "2026-06-22", now: Date(timeIntervalSince1970: 0))
        let remembered = await corrections.correction(for: FoodCorrection.key(food: "BLT", unit: "serving"))
        #expect(remembered?.kcal == 320)                // per-unit at quantity 1 = 320

        // An UNEDITED estimate does not pollute the memory.
        let clean = FoodConfirmModel(parsed: ParsedFood(food: "Soup", quantity: 1, unit: "bowl", kcal: 200, nutritionConfidence: .estimated),
                                     method: .text, store: try makeStore(), corrections: corrections)
        _ = await clean.save(date: "2026-06-22", now: Date(timeIntervalSince1970: 0))
        #expect(await corrections.correction(for: FoodCorrection.key(food: "Soup", unit: "bowl")) == nil)
    }
}

@MainActor
@Suite("TextInputModel")
struct TextInputModelTests {

    private func makeStore() throws -> SwiftDataStore { try SwiftDataStore.make(inMemory: true) }

    @Test("autocomplete surfaces previously-eaten foods matching the query")
    func autocomplete() async throws {
        let store = try makeStore()
        try await store.add(Entry(id: "1", date: "2026-06-20", timestamp: Date(timeIntervalSince1970: 1),
                                  food: "Chicken Breast", quantity: 150, unit: "g",
                                  kcal: 248, fat: 5, carbs: 0, protein: 46, method: .text))
        let model = TextInputModel(store: store, parser: StubParser(result: .init(food: "x", quantity: 1, unit: "g", kcal: 0)),
                                   units: .metric)
        model.query = "chick"
        await model.updateSuggestions()
        #expect(model.suggestions.map(\.food) == ["Chicken Breast"])
    }

    @Test("parse routes the query through the FoodParsing seam")
    func parseRoutes() async throws {
        let result = ParsedFood(food: "Oatmeal", quantity: 1, unit: "bowl", kcal: 300)
        let model = TextInputModel(store: try makeStore(), parser: StubParser(result: result),
                                   units: .metric)
        model.query = "a bowl of oatmeal"
        #expect(try await model.parse() == result)
    }

}
