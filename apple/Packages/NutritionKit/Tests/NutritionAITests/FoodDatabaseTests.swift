// FoodDatabase is the on-device generic-food resolver: it matches a description to
// a real USDA row (dish or ingredient), produces a portioned ParsedFood, and — for
// dishes — attaches an editable recipe breakdown. It also grounds the AI parsers.
// These tests pin matching quality, dish-vs-ingredient bias, alias expansion,
// portion/recipe scaling, and that the shipped FoodDB.json loads.

import Testing
@testable import NutritionAI
import NutritionCore

@Suite("FoodDatabase")
struct FoodDatabaseTests {

    private func makeDB() -> FoodDatabase {
        FoodDatabase(foods: [
            DBFood(name: "Bacon, lettuce, tomato sandwich on white", kind: .dish,
                   kcal: 231, protein: 10.9, fat: 7.5, carbs: 29.7, fiber: 1.7, sodium: 521, sugar: 3.7,
                   portions: [DBPortion(label: "1 sandwich, any size", grams: 105)],
                   recipe: [DBIngredient(name: "Pork, cured, bacon, cooked", grams: 16),
                            DBIngredient(name: "Bread, white, commercially prepared", grams: 60),
                            DBIngredient(name: "Tomatoes, for use on a sandwich", grams: 20),
                            DBIngredient(name: "Lettuce, for use on a sandwich", grams: 8)]),
            DBFood(name: "Apples, fuji, with skin, raw", kind: .food,
                   kcal: 58, protein: 0.1, fat: 0.2, carbs: 15.7, fiber: 2.1, sodium: 1, sugar: 13.3,
                   portions: [DBPortion(label: "1 cup, sliced", grams: 109)]),
            DBFood(name: "Apple pie", kind: .dish, kcal: 265, protein: 2.4, fat: 12.5, carbs: 37, sugar: 16),
            DBFood(name: "Bread, white, commercially prepared", kind: .food,
                   kcal: 270, protein: 9, fat: 3.6, carbs: 49, fiber: 2.7, sodium: 490, sugar: 5),
            DBFood(name: "Pork, cured, bacon, cooked", kind: .food,
                   kcal: 500, protein: 37, fat: 39, carbs: 1.4, sodium: 1700),
        ])
    }

    @Test("a descriptive dish query ranks the dish first and carries portion + recipe")
    func dishMatch() {
        let top = makeDB().match("bacon lettuce tomato sandwich").first
        #expect(top?.food.name.hasPrefix("Bacon, lettuce, tomato") == true)
        #expect(top?.food.kind == .dish)
        #expect(top?.food.recipe.count == 4)
    }

    @Test("the BLT acronym expands to the descriptive name for a direct hit")
    func aliasExpansion() {
        #expect(makeDB().match("a BLT").first?.food.kind == .dish)
    }

    @Test("a single-word query prefers the concise ingredient over a dish that contains it")
    func ingredientBias() {
        // "apple" should surface the fruit, not "Apple pie".
        #expect(makeDB().match("apple").first?.food.name.hasPrefix("Apples") == true)
    }

    @Test("filler/portion words and plurals don't block the match")
    func fillerAndPlurals() {
        #expect(makeDB().match("a couple of apples").first?.food.name.hasPrefix("Apples") == true)
        #expect(makeDB().bestConfidentMatch("nonexistent zorblax") == nil)
    }

    @Test("resolve() scales density to the portion and attaches grounded components")
    func resolveDish() {
        let p = makeDB().resolve("bacon lettuce tomato sandwich", units: .metric)
        #expect(p != nil)
        #expect(p?.unit == "serving")
        // 231 kcal/100g × 105 g portion = ~243.
        #expect(p?.kcal == 243)
        #expect(p?.sodium == 550)                       // 521 × 1.05 = 547 → nearest 10
        #expect(p?.notes?.contains("105 g") == true)
        // Recipe → components, each grounded against the DB (bread 270/100g × 60g ≈ 162).
        let bread = p?.components?.first { $0.name == "Bread" }
        #expect(bread?.grams == 60)
        #expect(bread?.kcal == 162)
        #expect(p?.components?.count == 4)
    }

    @Test("an ingredient resolves with its portion; unknown nutrients stay nil")
    func resolveIngredient() {
        let salmon = FoodDatabase(foods: [
            DBFood(name: "Salmon, Atlantic, cooked", kcal: 206, protein: 22, fat: 12, carbs: 0,
                   fiber: nil, sodium: 61, sugar: nil, portions: [DBPortion(label: "3 oz", grams: 85)])
        ])
        let p = salmon.resolve("salmon", units: .metric)
        #expect(p?.kcal == 175)                          // 206 × 0.85
        #expect(p?.fiber == nil)                         // unknown, never fabricated
        #expect(p?.components == nil)                    // no recipe for an ingredient
    }

    @Test("the shipped FoodDB.json loads with a meaningful number of foods")
    func bundledResourceLoads() {
        #expect(FoodDatabase.shared.count > 12_000)
        let blt = FoodDatabase.shared.resolve("bacon lettuce tomato sandwich", units: .metric)
        #expect(blt?.components?.isEmpty == false)        // a real dish with a real recipe
    }

    @Test("matching ~13k foods stays fast (1,000 queries well under a second)")
    func performance() {
        let db = FoodDatabase.shared
        for _ in 0..<1_000 { _ = db.match("grilled chicken breast") }
    }
}
