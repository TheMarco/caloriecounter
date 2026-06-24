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

    // MARK: - Real-world query quality (against the shipped DB)

    @Test("compound 'chili cheese dog' / 'hotdog…' queries resolve to a chili hot dog WITH a bun")
    func chiliDogQueries() {
        for q in ["chili cheese dog", "chili dog", "hotdog with chili and cheese", "chili cheese hot dog"] {
            let name = FoodDatabase.shared.bestConfidentMatch(q)?.name.lowercased() ?? ""
            #expect(name.contains("hot dog"), "‘\(q)’ → ‘\(name)’ should be a hot dog")
            #expect(name.contains("chili"), "‘\(q)’ → ‘\(name)’ should include chili")
            #expect(name.contains("bun") || name.contains("bread"), "‘\(q)’ → ‘\(name)’ should include a bun")
            #expect(!name.contains("no bun"), "‘\(q)’ shouldn't pick the bun-less variant")
            #expect(!name.contains("cheese dip"), "‘\(q)’ shouldn't pick cheese dip")
        }
    }

    @Test("'hotdog' (one word) resolves to a hot dog, not a bun/roll")
    func hotdogCompoundWord() {
        let name = FoodDatabase.shared.bestConfidentMatch("hotdog")?.name.lowercased() ?? ""
        #expect(name.contains("hot dog"))
        #expect(!name.contains("roll"))
    }

    @Test("bare single-food words resolve to the everyday form, not a processed variant")
    func bareSingleFoods() {
        func name(_ q: String) -> String { FoodDatabase.shared.bestConfidentMatch(q)?.name.lowercased() ?? "" }
        // The query word leads the result, and obvious processed/derived forms are avoided.
        #expect(name("apple").contains("apple") && !name("apple").contains("dried"))
        #expect(name("rice").contains("rice") && !name("rice").contains("flour") && !name("rice").contains("cracker"))
        #expect(name("milk").hasPrefix("milk"))
        #expect(name("cheese").hasPrefix("cheese") && !name("cheese").contains("spread"))
        #expect(name("chicken").contains("chicken") && !name("chicken").contains("spread") && !name("chicken").contains("feet"))
    }

    /// Regression guard for the "coffee → 810 kcal" class found in the deep sweep:
    /// a bare food/drink must resolve to ITSELF, not an accompaniment or a dish that
    /// merely starts with the word. (Pins behavior against the shipped FoodDB.json.)
    @Test("real-world queries don't resolve to the wrong food")
    func noWrongFoodMatches() {
        func food(_ q: String) -> DBFood {
            FoodDatabase.shared.bestConfidentMatch(q) ?? DBFood(name: "NONE", kcal: -1, protein: 0, fat: 0, carbs: 0)
        }
        // (query, must-contain stem, banned substrings, max kcal/100g or nil)
        let cases: [(String, String, [String], Double?)] = [
            ("coffee", "coffee", ["creamer", "cake", "liqueur", "beans"], 20),
            ("black coffee", "coffee", ["bean", "russian", "dip"], 20),
            ("tea", "tea", ["cake"], 30),
            ("water", "water", [], 5),
            ("milk", "milk", ["shake", "chocolate"], 80),
            ("almond milk", "almond milk", ["chocolate"], 60),
            ("grapes", "grape", ["leave", "leaf", "juice"], 90),
            ("strawberries", "strawberr", ["milk"], 70),
            ("honey", "honey", ["sausage", "roll"], nil),
            ("tuna", "tuna", ["sandwich", "salad", "wrap"], nil),
            ("apple", "apple", ["pie", "juice", "dried", "sauce"], 90),
            ("banana", "banana", ["bread", "chip"], 120),
            ("egg", "egg", ["white sandwich", "substitute"], nil),
            ("orange juice", "orange juice", [], 70),
            ("sweet potato", "sweet potato", ["tot", "chip", "fries"], 130),
            // Deep-sweep fixes (was: cocktails, diet variants, processed/composite
            // forms, brand collisions). Pins them against the shipped FoodDB.json.
            ("black coffee with sugar", "coffee", ["russian", "bean"], 30),  // was "Black Russian"
            ("ginger ale", "ginger ale", ["whiskey", "alcoholic"], 50),      // was "Whiskey and ginger ale"
            ("cream cheese", "cream cheese", ["light", "low"], nil),          // was "…, light"
            ("sour cream", "sour cream", ["light", "low"], nil),             // was "…, light"
            ("parmesan", "parmesan", ["topping", "fat free", "free"], nil),   // was "…topping, fat free"
            ("mozzarella", "mozzarella", ["fried", "dressing", "topping"], nil), // was "fried mozzarella"
            ("block of cheddar", "cheddar", ["cream cheese", "cottage"], nil), // was "Cream cheese…block"
            ("cheese curds", "cheddar", ["cottage", "sandwich"], nil),       // was "cottage, dry curd"
            ("butter chicken with naan", "chicken", [], 400),                // was "Butter, NFS" (743 kcal!)
            ("passion fruit", "passion fruit", ["nectar", "juice"], 110),    // was "…nectar"
            ("cantaloupe", "cantaloupe", ["nectar"], 60),                    // was "…nectar"
            ("russet potato", "potato", ["pancake", "chip", "fries"], 140),  // was "Potato pancake"
            ("meatballs", "meatball", ["sandwich", "sub"], nil),             // was "Meatball…sub"
            ("big mac", "mac", ["macaroni"], nil),                            // was "Macaroni…" (mac alias)
            ("milk chocolate", "chocolate", ["cocoa", "beverage"], nil),     // was "…hot cocoa" beverage
            ("onion rings", "onion", ["flavored"], nil),                     // was "Onion flavored rings"
            ("bolognese sauce", "sauce", ["barbecue", "bbq"], nil),          // decomposed component → meat sauce, not BBQ
        ]
        for (q, must, banned, maxKcal) in cases {
            let f = food(q)
            let n = f.name.lowercased()
            #expect(n.contains(must), "‘\(q)’ → ‘\(f.name)’ should contain ‘\(must)’")
            for b in banned { #expect(!n.contains(b), "‘\(q)’ → ‘\(f.name)’ shouldn't be a ‘\(b)’") }
            if let maxKcal { #expect(f.kcal <= maxKcal, "‘\(q)’ → ‘\(f.name)’ \(Int(f.kcal)) kcal/100g exceeds \(Int(maxKcal))") }
        }
    }

    /// A single prepared food must NOT surface its raw FNDDS recipe as a breakdown:
    /// "cinnamon toast" was decomposing into flour + oil + sugar + "Iron as
    /// ingredient", and "english cucumber" into cucumber + oil + salt. Only genuine
    /// multi-food dishes (BLT) keep a breakdown.
    @Test("simple foods don't show a raw-ingredient breakdown; real dishes still do")
    func noBreakdownForSingleFoods() {
        let db = FoodDatabase.shared
        #expect(db.resolve("cinnamon toast", units: .metric)?.components?.isEmpty ?? true,
                "‘cinnamon toast’ shouldn't show a flour/enrichment breakdown")
        #expect(db.resolve("english cucumber", units: .metric)?.components?.isEmpty ?? true,
                "‘english cucumber’ shouldn't show an oil/salt breakdown")
        // …but a genuine composite dish still decomposes.
        #expect(db.resolve("bacon lettuce tomato sandwich", units: .metric)?.components?.isEmpty == false)
    }

    /// A described dish must not resolve to a condiment/component standing in for it
    /// ("fettuccine alfredo" → "Alfredo sauce") — that's a partial answer pretending to
    /// be the whole thing. The Analyze chain then defers to a whole-dish estimate.
    @Test("a condiment posing as a described dish defers (no partial 'sauce' answer)")
    func partialComponentMatchDefers() {
        let db = FoodDatabase.shared
        func name(_ q: String) -> String? { db.confidentWholeMatch(q)?.name.lowercased() }
        // Sauce standing in for a pasta dish → defer (nil).
        #expect(db.confidentWholeMatch("fettuccine alfredo") == nil)
        #expect(db.confidentWholeMatch("fettucine alfredo with parmesan") == nil)
        #expect(db.confidentWholeMatch("chicken alfredo") == nil)
        // …but the condiment ITSELF, or a match that covers the whole query, stays.
        #expect(name("alfredo sauce")?.contains("alfredo") == true)
        #expect(name("pesto")?.contains("pesto") == true)
        #expect(name("black coffee")?.contains("coffee") == true)   // dropped modifier, not a component
        #expect(name("caesar salad")?.contains("caesar") == true)   // covers the whole query
        #expect(name("chicken curry")?.contains("chicken") == true)
    }

    @Test("base staples and enrichment lines are classified as non-food ingredients")
    func baseOrEnrichmentClassifier() {
        for n in ["Flour", "Oil", "Sugars", "Salt", "Vegetable oil", "Table fat",
                  "Iron as ingredient", "Vitamin B composite", "Folic acid as ingredient", "Fiber"] {
            #expect(FoodDatabase.isBaseOrEnrichment(n), "‘\(n)’ should be base/enrichment")
        }
        for n in ["Bacon", "Lettuce", "Tomato", "Cucumber", "Peanut butter", "Cheese"] {
            #expect(!FoodDatabase.isBaseOrEnrichment(n), "‘\(n)’ is a real food")
        }
    }
}
