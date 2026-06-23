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

    @Test("a compatible unit change preserves nutrition (same physical amount)")
    func compatibleUnitChangePreservesNutrition() throws {
        let bread = ParsedFood(food: "Bread", quantity: 100, unit: "g", kcal: 244, fat: 4, carbs: 49, protein: 11)
        let model = FoodConfirmModel(parsed: bread, method: .barcode, store: try makeStore())
        #expect(model.kcal == 244)
        // The same 100 g expressed as ≈3.53 oz — calories stay the same.
        model.unit = "oz"
        model.quantityText = "3.5274"
        #expect(model.kcal == 244)
        // Doubling the oz amount doubles the calories.
        model.quantityText = "7.0549"
        #expect(model.kcal == 488)
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
        let model = TextInputModel(store: store, parser: StubParser(result: .init(food: "x", quantity: 1, unit: "g", kcal: 0)), units: .metric)
        model.query = "chick"
        await model.updateSuggestions()
        #expect(model.suggestions.map(\.food) == ["Chicken Breast"])
    }

    @Test("parse routes the query through the FoodParsing seam")
    func parseRoutes() async throws {
        let result = ParsedFood(food: "Oatmeal", quantity: 1, unit: "bowl", kcal: 300)
        let model = TextInputModel(store: try makeStore(), parser: StubParser(result: result), units: .metric)
        model.query = "a bowl of oatmeal"
        #expect(try await model.parse() == result)
    }
}
