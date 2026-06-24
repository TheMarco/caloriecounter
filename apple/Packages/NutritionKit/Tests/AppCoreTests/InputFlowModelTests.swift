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

    @Test("advanced nutrition is seeded, editable, and marks user-edited; blank → nil")
    func advancedNutrition() throws {
        let parsed = ParsedFood(food: "Bran", quantity: 1, unit: "bowl", kcal: 200,
                                fiber: 12, sodium: 210, sugar: nil, nutritionConfidence: .barcode)
        let model = FoodConfirmModel(parsed: parsed, method: .barcode, store: try makeStore())
        // Seeded from the parse.
        #expect(model.fiberText == "12")
        #expect(model.sodiumText == "210")
        #expect(model.sugarText == "")

        // Unedited → keeps the parse source and values.
        #expect(model.makeEntry().fiber == 12)
        #expect(model.makeEntry().nutritionConfidence == .barcode)

        // Editing a value flips the source to .userEdited; a blank stays nil.
        model.fiberText = "9"
        model.sodiumText = ""
        let e = model.makeEntry()
        #expect(e.fiber == 9)
        #expect(e.sodium == nil)
        #expect(e.nutritionConfidence == .userEdited)
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
        let model = TextInputModel(store: store, parser: StubParser(result: .init(food: "x", quantity: 1, unit: "g", kcal: 0)),
                                   foodSearch: StaticFoodSearch(), foodDatabase: StaticFoodDatabase(), units: .metric)
        model.query = "chick"
        await model.updateSuggestions()
        #expect(model.suggestions.map(\.food) == ["Chicken Breast"])
    }

    @Test("parse routes the query through the FoodParsing seam")
    func parseRoutes() async throws {
        let result = ParsedFood(food: "Oatmeal", quantity: 1, unit: "bowl", kcal: 300)
        let model = TextInputModel(store: try makeStore(), parser: StubParser(result: result),
                                   foodSearch: StaticFoodSearch(), foodDatabase: StaticFoodDatabase(), units: .metric)
        model.query = "a bowl of oatmeal"
        #expect(try await model.parse() == result)
    }

    @Test("a settled query surfaces branded product matches from the search seam")
    func productMatches() async throws {
        let match = ParsedFood(food: "Chobani Greek Yogurt", quantity: 1, unit: "serving",
                               kcal: 120, nutritionConfidence: .barcode)
        let model = TextInputModel(store: try makeStore(),
                                   parser: StubParser(result: .init(food: "x", quantity: 1, unit: "g", kcal: 0)),
                                   foodSearch: StaticFoodSearch(results: [match]), foodDatabase: StaticFoodDatabase(),
                                   units: .metric, searchDebounceMilliseconds: 0)
        model.query = "greek yogurt"
        await model.searchProducts()
        #expect(model.productMatches == [match])
    }

    @Test("short queries don't trigger a product search")
    func productMatchesShortQuery() async throws {
        let model = TextInputModel(store: try makeStore(),
                                   parser: StubParser(result: .init(food: "x", quantity: 1, unit: "g", kcal: 0)),
                                   foodSearch: StaticFoodSearch(results: [.init(food: "X", quantity: 1, unit: "g", kcal: 1)]),
                                   foodDatabase: StaticFoodDatabase(),
                                   units: .metric, searchDebounceMilliseconds: 0)
        model.query = "ab"
        await model.searchProducts()
        #expect(model.productMatches.isEmpty)
    }

    @Test("a query surfaces on-device USDA database matches; short queries don't")
    func databaseMatches() async throws {
        let dish = ParsedFood(food: "Bacon, lettuce, tomato sandwich", quantity: 1, unit: "serving", kcal: 243,
                              nutritionConfidence: .estimated,
                              components: [FoodComponent(name: "Bacon", grams: 16, kcal: 84)])
        let model = TextInputModel(store: try makeStore(),
                                   parser: StubParser(result: .init(food: "x", quantity: 1, unit: "g", kcal: 0)),
                                   foodSearch: StaticFoodSearch(), foodDatabase: StaticFoodDatabase(results: [dish]),
                                   units: .metric)
        model.query = "blt"
        await model.searchDatabase()
        #expect(model.dbMatches == [dish])

        model.query = "bl"
        await model.searchDatabase()
        #expect(model.dbMatches.isEmpty)
    }
}
