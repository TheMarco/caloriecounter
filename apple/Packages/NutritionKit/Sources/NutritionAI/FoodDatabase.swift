// On-device generic-food database — the primary resolver for typed/spoken foods
// that aren't a scanned brand. Backed by the bundled `FoodDB.json` (~13k USDA
// foods: FNDDS composite DISHES with recipes + SR Legacy / Foundation ingredients).
//
// Two jobs:
//   • Direct resolution — match a description to a real row and produce a ParsedFood
//     with a sensible portion and, for dishes, an editable ingredient breakdown.
//   • Grounding — hand per-100g densities to the Foundation Models / heuristic
//     parsers so their estimates use measured numbers (replaces the old USDAFoodIndex).
//
// Matching is a fast, dependency-free token-overlap score (stem plurals, drop
// portion/filler words, weight the primary token + whole-phrase hits), plus a light
// dish-vs-ingredient bias: multi-word queries lean toward dishes ("chicken parm"),
// single words toward concise ingredients ("apple" → the fruit, not "apple pie").

import Foundation
import NutritionCore

/// A household serving for a food: a label and its weight in grams.
public struct DBPortion: Sendable, Equatable {
    public let label: String
    public let grams: Double
    public init(label: String, grams: Double) { self.label = label; self.grams = grams }
}

/// One recipe line of a dish (FNDDS `inputFoods`): an ingredient and its grams.
public struct DBIngredient: Sendable, Equatable {
    public let name: String
    public let grams: Double
    public init(name: String, grams: Double) { self.name = name; self.grams = grams }
}

/// A database food with per-100g densities, portions, and (dishes) a recipe.
public struct DBFood: Sendable, Equatable {
    public enum Kind: String, Sendable { case dish, food }

    public let name: String
    public let kind: Kind
    public let kcal: Double        // per 100 g
    public let protein: Double
    public let fat: Double
    public let carbs: Double
    public let fiber: Double?
    public let sodium: Double?     // mg
    public let sugar: Double?
    public let portions: [DBPortion]
    public let recipe: [DBIngredient]

    public init(name: String, kind: Kind = .food,
                kcal: Double, protein: Double, fat: Double, carbs: Double,
                fiber: Double? = nil, sodium: Double? = nil, sugar: Double? = nil,
                portions: [DBPortion] = [], recipe: [DBIngredient] = []) {
        self.name = name; self.kind = kind
        self.kcal = kcal; self.protein = protein; self.fat = fat; self.carbs = carbs
        self.fiber = fiber; self.sodium = sodium; self.sugar = sugar
        self.portions = portions; self.recipe = recipe
    }

    /// Per-100g density scaled to an absolute gram weight.
    public func scaled(toGrams grams: Double) -> (kcal: Double, fat: Double, carbs: Double, protein: Double, fiber: Double?, sodium: Double?, sugar: Double?) {
        let r = grams / 100
        return (kcal * r, fat * r, carbs * r, protein * r,
                fiber.map { $0 * r }, sodium.map { $0 * r }, sugar.map { $0 * r })
    }
}

/// A scored retrieval result.
public struct DBMatch: Sendable, Equatable {
    public let food: DBFood
    public let score: Double
}

public final class FoodDatabase: FoodDatabaseQuerying, Sendable {

    /// Shared, lazily-loaded instance over the bundled resource.
    public static let shared = FoodDatabase()

    private let foods: [DBFood]
    /// Parallel to `foods`: each food's stemmed token set + primary token.
    private let tokenized: [(tokens: Set<String>, primary: String, joined: String)]
    /// Exact normalized-name → food, for O(1) recipe-ingredient grounding (USDA
    /// `inputFoods` names usually equal a real row's name) — fast enough to run while
    /// the user types.
    private let byName: [String: DBFood]
    /// Inverse document frequency per token: rare, specific words ("dog", "frankfurter")
    /// weigh far more than common ones ("cheese", "sauce", "with") so a query matches on
    /// the word that actually identifies the food, not on a shared modifier.
    private let idf: [String: Double]
    /// idf for a token no food contains (maximally specific).
    private let maxIdf: Double

    public convenience init() {
        self.init(foods: Self.loadBundled())
    }

    /// Inject a fixed list (tests/previews).
    public init(foods: [DBFood]) {
        self.foods = foods
        let tokenized = foods.map(Self.tokenizeEntry)
        self.tokenized = tokenized
        self.byName = Dictionary(foods.map { ($0.name.lowercased(), $0) }, uniquingKeysWith: { a, _ in a })

        let n = Double(max(foods.count, 1))
        var df: [String: Int] = [:]
        for entry in tokenized { for token in entry.tokens { df[token, default: 0] += 1 } }
        self.idf = df.mapValues { log(n / Double($0)) }
        self.maxIdf = log(n)
    }

    public var count: Int { foods.count }

    private static func tokenizeEntry(_ food: DBFood) -> (tokens: Set<String>, primary: String, joined: String) {
        let toks = tokenize(food.name)
        return (Set(toks), toks.first ?? "", toks.joined(separator: " "))
    }

    // MARK: - Retrieval

    /// Best matches for a free-text query, strongest first (≤ `limit`, above a floor).
    public func match(_ query: String, limit: Int = 5) -> [DBMatch] {
        // Whole-query rewrites for names whose head/primary token literally collides
        // with a different food ("big mac" → macaroni via alias, "candy cane" → sugar
        // cane, "milk chocolate" → hot cocoa). A phrase hit replaces the query outright
        // and SKIPS per-token aliasing, so "big mac" isn't re-expanded to "macaroni".
        let baseTokens = Self.tokenize(query)
        let rawTokens = Self.phraseAliases[baseTokens.joined(separator: " ")]
            .map(Self.tokenize) ?? Self.expandAliases(baseTokens)
        let q = rawTokens.filter { !Self.fillerWords.contains($0) }
        guard !q.isEmpty else { return [] }
        let qSet = Set(q)
        let joinedQuery = q.joined(separator: " ")
        let multiWord = qSet.count >= 2
        // The head noun. For "X with Y…", it's the last real word BEFORE the first
        // connector — the thing being described, which may itself be multi-word
        // ("butter chicken with naan" → chicken, "hotdog with chili" → dog). For a
        // plain "A B C" it's the last word.
        let connectorIdx = rawTokens.firstIndex { Self.connectors.contains($0) }
        let head: String?
        if let connectorIdx {
            head = rawTokens[..<connectorIdx].last { !Self.fillerWords.contains($0) } ?? q.first
        } else {
            head = q.last
        }

        // Total query weight (denominator), weighting each word by its specificity.
        let totalWeight = qSet.reduce(0.0) { $0 + (idf[$1] ?? maxIdf) }

        var scored: [DBMatch] = []
        scored.reserveCapacity(foods.count)
        for (i, food) in foods.enumerated() {
            let entry = tokenized[i]
            let overlap = qSet.intersection(entry.tokens)
            guard !overlap.isEmpty else { continue }

            // Fraction of the query's SPECIFICITY found, not just its word count — so
            // matching "dog" (rare) beats matching "cheese" (common).
            let matchedWeight = overlap.reduce(0.0) { $0 + (idf[$1] ?? maxIdf) }
            var score = totalWeight > 0 ? matchedWeight / totalWeight : 0
            if qSet.contains(entry.primary) { score += 0.6 }                 // primary-word hit
            // Head-noun hit: the food the user actually means (see `head`) — weighted
            // like the primary, so it beats a food that only matched a modifier. When
            // the head noun is ABSENT, penalize: the match latched onto a modifier/side
            // word, not what the user asked for ("buffalo wings" → buffalo steak).
            if let head {
                if entry.tokens.contains(head) { score += 0.6 }
                else { score -= 0.5 }
            }
            score += 0.2 * Double(overlap.count) / Double(entry.tokens.count) // prefer concise names
            if entry.joined.contains(joinedQuery) { score += 0.4 }           // whole-phrase containment
            // USDA's "not further specified" generic form ("Milk, NFS") — the canonical
            // as-eaten entry. Only a BRIEF name counts (so "Milk, NFS" qualifies but the
            // composite "Egg foo yung, NFS" doesn't); a small boost so it wins ties
            // without overriding a match that covers MORE of the query.
            // Generic-form boost ("Milk, NFS"), single-word queries only, and ONLY when
            // the row's real words are all in the query — so "Milk, NFS" boosts for
            // "milk" but "Strawberry milk, NFS"/"Coffee creamer, NFS" don't for
            // "strawberries"/"coffee" (they carry an extra food noun the user didn't ask).
            let hasNFS = entry.tokens.contains("nfs") || entry.tokens.contains("ns")
            let isGenericNFS = !multiWord && hasNFS
                && entry.tokens.subtracting(Self.genericMarkers).isSubset(of: qSet)
            if isGenericNFS { score += 0.2 }
            // Dish-vs-ingredient bias: a dish that genuinely covers ≥2 of the query's
            // words is likely what a multi-word description means; a single-word query
            // leans to the concise ingredient (or the generic NFS form).
            if multiWord && food.kind == .dish && overlap.count >= 2 { score += 0.3 }
            else if !multiWord && (food.kind == .food || isGenericNFS) { score += 0.2 }
            // Penalize non-prototypical/processed forms the user DIDN'T ask for, so a
            // bare "apple" prefers the raw fruit over "Apples, dried, sulfured" and
            // "chicken" prefers the meat over "Chicken spread".
            let processed = entry.tokens.subtracting(qSet).intersection(Self.processedQualifiers)
            score -= 0.45 * Double(min(processed.count, 3))

            scored.append(DBMatch(food: food, score: score))
        }

        return scored
            .filter { $0.score >= 0.5 }
            .sorted { $0.score > $1.score }
            .prefix(limit)
            .map { $0 }
    }

    /// The single best match if it clears a high-confidence bar (grounding / direct
    /// resolution shouldn't fire on a weak partial overlap).
    public func bestConfidentMatch(_ query: String, minScore: Double = 1.1) -> DBFood? {
        guard let top = match(query, limit: 1).first, top.score >= minScore else { return nil }
        return top.food
    }

    /// A confident match suitable as a FINAL ANSWER (stricter than `bestConfidentMatch`,
    /// which is fine for grounding). Rejects a condiment/component standing in for the
    /// dish the user described — "fettuccine alfredo" must NOT resolve to "Alfredo
    /// sauce", "chicken alfredo" must not resolve to the sauce either. The caller then
    /// defers to a whole-dish estimate. The match is allowed to ADD a component word
    /// only when it still covers the whole query ("pesto" → "Pesto sauce", "ranch" →
    /// "Dressing, ranch", "alfredo" → "Alfredo sauce" — the user asked for just that).
    func confidentWholeMatch(_ query: String, minScore: Double = 1.1) -> DBFood? {
        guard let top = match(query, limit: 1).first, top.score >= minScore else { return nil }
        if isComponentStandIn(top.food, forQuerySet: querySet(query)) { return nil }
        return top.food
    }

    /// The query tokens the matcher scores against (alias/phrase expanded, fillers removed).
    private func querySet(_ query: String) -> Set<String> {
        let base = Self.tokenize(query)
        let raw = Self.phraseAliases[base.joined(separator: " ")].map(Self.tokenize) ?? Self.expandAliases(base)
        return Set(raw.filter { !Self.fillerWords.contains($0) })
    }

    /// Whether a row is a condiment/component standing in for the described dish: its
    /// name carries a component word ("sauce", "dressing"…) AND it doesn't cover the
    /// whole query — "Alfredo sauce" for "fettuccine alfredo", or "Spaghetti sauce with
    /// meat" for "spaghetti with meat sauce and parmesan". Such a row is fine for
    /// grounding, but a trap as a final answer OR a visible top suggestion.
    private func isComponentStandIn(_ food: DBFood, forQuerySet qSet: Set<String>) -> Bool {
        let tokens = Set(Self.tokenize(food.name))
        guard !tokens.isDisjoint(with: Self.componentWords) else { return false }
        return !qSet.isSubset(of: tokens)
    }

    /// Top foods as grounding references for the AI parsers (per-100g densities).
    public func referenceFoods(_ query: String, limit: Int = 3) -> [DBFood] {
        match(query, limit: limit).map(\.food)
    }

    // MARK: - Direct resolution → ParsedFood

    /// Resolve a confident match for `query` into a ParsedFood (with a portion and,
    /// for dishes, an editable ingredient breakdown). Nil when nothing matches well.
    /// `keepingName` overrides the food name with the user's wording (the Analyze
    /// path keeps "apple"; a tapped suggestion keeps the canonical DB name).
    public func resolve(_ query: String, units: UnitSystem, keepingName: String? = nil) -> ParsedFood? {
        guard let food = confidentWholeMatch(query) else { return nil }
        return parsedFood(for: food, units: units, nameOverride: keepingName)
    }

    /// Top suggestions for a query, each resolved to a portioned ParsedFood (with
    /// dish breakdowns). Local + fast — safe to call on every keystroke.
    public func suggestions(_ query: String, units: UnitSystem, limit: Int = 5) -> [ParsedFood] {
        // Filter out condiment stand-ins ("Alfredo sauce" for "penne alfredo") so the
        // visible "Foods" list can't trap the user into logging just the sauce — the
        // same guard Analyze applies. Fetch a few extra to backfill what's dropped.
        let qSet = querySet(query)
        return match(query, limit: limit + 5)
            .filter { !isComponentStandIn($0.food, forQuerySet: qSet) }
            .prefix(limit)
            .map { parsedFood(for: $0.food, units: units) }
    }

    /// Build a ParsedFood for a specific row: scale its density to the best portion
    /// (defaulting to 100 g) and attach recipe components grounded against the DB.
    public func parsedFood(for food: DBFood, units: UnitSystem, nameOverride: String? = nil) -> ParsedFood {
        let portion = food.portions.first
        let grams = portion?.grams ?? 100
        let s = food.scaled(toGrams: grams)

        let rawComponents: [FoodComponent] = food.recipe.map { ing in
            // Ground each ingredient via the O(1) exact-name index; else grams-only.
            if let match = byName[ing.name.lowercased()] {
                let m = match.scaled(toGrams: ing.grams)
                return FoodComponent(name: Self.cleanIngredientName(ing.name), grams: ing.grams,
                                     kcal: m.kcal.rounded(), fat: round1(m.fat), carbs: round1(m.carbs),
                                     protein: round1(m.protein), fiber: m.fiber.map { $0.rounded() },
                                     sodium: m.sodium.map { ($0 / 10).rounded() * 10 }, sugar: m.sugar.map { $0.rounded() })
            }
            return FoodComponent(name: Self.cleanIngredientName(ing.name), grams: ing.grams, kcal: 0)
        }
        // Only show an editable breakdown for a GENUINE multi-food dish (BLT →
        // bacon/bread/tomato/lettuce). A single prepared food's FNDDS recipe is just
        // base ingredients + enrichment (flour, oil, sugar, "Iron as ingredient"…) —
        // useless and alarming as a breakdown ("cinnamon toast" / "english cucumber"),
        // so suppress it and let the food's own macros stand. Needs ≥2 components that
        // are actual foods, not staples/enrichment.
        let realFoodCount = rawComponents.filter { !Self.isBaseOrEnrichment($0.name) }.count
        // FNDDS recipe grams are often the full BATCH (mac & cheese: 1614 g / 3242 kcal)
        // while the row total is per serving (513 kcal). Scale every component so the
        // breakdown sums to the AUTHORITATIVE row total — the confirm screen totals the
        // components, so without this it would save 3242 kcal instead of 513.
        let rawKcalSum = rawComponents.reduce(0.0) { $0 + $1.kcal }
        let components: [FoodComponent]?
        if realFoodCount >= 2, rawKcalSum > 0 {
            let ratio = s.kcal / rawKcalSum
            components = rawComponents.map { $0.scaled(toGrams: $0.grams * ratio) }
        } else {
            components = nil
        }

        let note: String? = portion.map { "Per serving: \($0.label) (\(Int($0.grams.rounded())) g)" }
        return ParsedFood(
            food: nameOverride ?? food.name, quantity: 1, unit: "serving",
            kcal: s.kcal.rounded(), fat: round1(s.fat), carbs: round1(s.carbs), protein: round1(s.protein),
            notes: note,
            fiber: s.fiber.map { $0.rounded() },
            sodium: s.sodium.map { ($0 / 10).rounded() * 10 },
            sugar: s.sugar.map { $0.rounded() },
            nutritionConfidence: .estimated,
            components: components
        )
    }

    private func round1(_ v: Double) -> Double { (v * 10).rounded() / 10 }

    // MARK: - Normalization

    /// USDA ingredient names are verbose ("Tomatoes, for use on a sandwich"); show
    /// just the head noun phrase before the first comma for the breakdown UI.
    static func cleanIngredientName(_ name: String) -> String {
        let head = name.split(separator: ",").first.map(String.init) ?? name
        return head.trimmingCharacters(in: .whitespaces)
    }

    /// Whether a recipe ingredient is a base staple or an FNDDS enrichment line
    /// rather than a distinct food — i.e. noise that shouldn't drive a breakdown.
    /// Catches "Flour"/"Oil"/"Sugar", "Vegetable oil"/"Table fat", "Vitamin …",
    /// and the "… as ingredient" enrichment markers ("Iron as ingredient").
    static func isBaseOrEnrichment(_ cleanedName: String) -> Bool {
        let lower = cleanedName.lowercased()
        if lower.contains("as ingredient") { return true }
        let words = lower.split(separator: " ").map(String.init)
        if let last = words.last, last == "oil" || last == "fat" { return true }   // "Vegetable oil", "Table fat"
        if let first = words.first, enrichmentFirstWords.contains(first) { return true }  // "Vitamin …", "Niacin"
        let singular = lower.hasSuffix("s") ? String(lower.dropLast()) : lower      // "Sugars" → "sugar"
        return baseIngredientNames.contains(singular)
    }

    private static let enrichmentFirstWords: Set<String> = [
        "vitamin", "niacin", "riboflavin", "thiamin", "thiamine", "folate", "folic",
    ]
    private static let baseIngredientNames: Set<String> = [
        "flour", "sugar", "oil", "salt", "water", "yeast", "shortening", "starch",
        "cornstarch", "leavening", "butter", "margarine", "lard", "syrup",
        "iron", "calcium", "zinc", "fiber", "fibre",
    ]

    /// Lowercase, split on non-alphanumerics, drop 1-char tokens, light plural stem.
    static func tokenize(_ text: String) -> [String] {
        text.lowercased()
            .split(whereSeparator: { !$0.isLetter && !$0.isNumber })
            .map { stem(String($0)) }
            .filter { $0.count > 1 }
    }

    /// Expand common acronyms/nicknames the user types into the descriptive words
    /// USDA actually uses (the DB calls a BLT "Bacon, lettuce, tomato sandwich"), so
    /// these still resolve to a direct match. Applied to the query only.
    static func expandAliases(_ tokens: [String]) -> [String] {
        tokens.flatMap { aliases[$0].map(tokenize) ?? [$0] }
    }

    /// Keys are in STEMMED form (expansion runs after `tokenize`): "veggies"→"veggy".
    /// Also splits closed compounds the USDA names write as two words ("hotdog" →
    /// "hot dog") so they still overlap.
    static let aliases: [String: String] = [
        "blt": "bacon lettuce tomato sandwich",
        "pbj": "peanut butter jelly sandwich",
        "bbq": "barbecue",
        "mac": "macaroni",
        "veggie": "vegetable",
        "veggy": "vegetable",
        "hotdog": "hot dog",
        "cheeseburger": "cheese burger",
        "milkshake": "milk shake",
    ]

    /// Whole-query rewrites (keys in STEMMED, tokenized-joined form — the same shape
    /// `tokenize(query).joined(separator:" ")` produces). These handle iconic names
    /// whose tokens collide with an unrelated food: the substitution bypasses per-token
    /// alias expansion, so "big mac" resolves to McDonald's burger instead of macaroni.
    /// Each target is verified to exist in the shipped FoodDB.json.
    static let phraseAliases: [String: String] = [
        "big mac": "mcdonald big mac",           // → "McDONALD'S, BIG MAC" (not Macaroni)
        "onion ring": "fried onion ring",        // → "Fried onion rings" (not flavored snack rings)
        "milk chocolate": "candies milk chocolate", // → "Candies, milk chocolate" (not hot cocoa)
        "candy cane": "candies hard",            // → "Candies, hard" (not Sugar cane beverage)
        "cheese curd": "cheddar",                // → "Cheese, Cheddar" (not cottage dry curd)
        "laughing cow": "cheese spread",         // → a cheese spread (not "Beef, cow head")
        "english cucumber": "cucumber raw",      // → raw cucumber (not "Cucumber, cooked")
        // Ground a decomposed "bolognese" sauce component to a meat-tomato sauce, not
        // "Sauce, barbecue". Keyed exactly so "spaghetti bolognese" (whole) is untouched.
        "bolognese": "meat sauce",
        "bolognese sauce": "meat sauce",
    ]

    /// Symmetric light stemmer (applied to both query and food tokens).
    static func stem(_ token: String) -> String {
        if token.count > 4, token.hasSuffix("ies") { return String(token.dropLast(3)) + "y" }
        if token.count > 3, token.hasSuffix("ses") { return String(token.dropLast(2)) }
        if token.count > 3, token.hasSuffix("s"), !token.hasSuffix("ss"), !token.hasSuffix("us") {
            return String(token.dropLast())
        }
        return token
    }

    /// Tokens marking a non-prototypical / processed / derived form. A bare query
    /// ("apple", "chicken") is penalized for these when it didn't ask for them, so
    /// the everyday form wins over dried/powdered/spread/juice/etc. variants. Cooking
    /// methods (raw, cooked, roasted…) are deliberately NOT here.
    static let processedQualifiers: Set<String> = [
        "dried", "dehydrated", "powder", "powdered", "substitute", "concentrate",
        "concentrated", "canned", "juice", "peel", "spread", "paste", "cracker",
        "chip", "sulfured", "imitation", "infant", "instant", "candied", "pickled",
        "freeze", "frozen", "flavored", "mix", "baby", "drink", "meatless", "nugget",
        "breaded", "bran", "crude", "soup", "sheep", "goat", "buffalo", "puff", "stick",
        "flour", "feet", "leave", "leaf", "bar",
        // Identity-changing accompaniments/forms — a "coffee creamer", "grape leaves",
        // "honey sausage", "tuna salad", "fish broth", "sweet potato tots" aren't the
        // base food. (Penalized only when the user DIDN'T type them; stemmed forms.)
        "creamer", "liqueur", "cake", "syrup", "sauce", "sausage", "broth", "tot",
        "wrap", "salad", "dip",
        // Flavor/variant qualifiers — a bare "egg"/"almond milk" should prefer the
        // plain form over "egg white"/"almond milk, chocolate". (Only when not typed.)
        "white", "chocolate",
        // Exclusion variants ("…, no bun", "…, no salt") — not the standard form.
        "no",
        // Sweetened-beverage forms of a whole food (passion fruit → "…nectar").
        "nectar", "sweetened",
        // Diet/reduced variants — a bare query wants the regular form, not the light one.
        // ("unsweetened" is intentionally NOT here — unsweetened almond/soy milk IS the
        // default people mean.)
        "light", "lite", "low", "lowfat", "reduced", "nonfat", "fatfree", "skim", "diet", "free",
        // Prepared-dish forms of a bare ingredient (meatballs → "meatball sub",
        // apple pie → "…filling"). NOTE: "sandwich"/"bowl" are intentionally excluded —
        // a hot dog legitimately resolves to its "…sandwich, on bun" row, and "bowl" is
        // already a portion/filler word.
        "sub", "burrito", "dressing", "filling", "patty", "croquette", "pancake", "coated",
        "flurry", "sundae", "glutinous", "spice", "extract", "topping", "fried",
        // Added-ingredient variants of a staple (bread → "Bread, egg", spaghetti →
        // "…spinach", greek yogurt → "…with oats"). Safe: only penalized when the user
        // didn't type them, so "egg"/"spinach"/"oatmeal" queries are unaffected.
        "egg", "spinach", "oat",
        // Alcoholic forms — a non-alcoholic query shouldn't land on a cocktail/spirit.
        "alcoholic", "whiskey", "vodka", "rum", "gin", "tequila", "cocktail", "russian",
        "margarita", "mojito", "martini", "daiquiri", "brandy", "bourbon", "sangria",
    ]

    /// Words that signal an "X with Y and Z" structure, where the head noun is the
    /// FIRST food word, not the last (so "hotdog with chili and cheese" → hotdog).
    static let connectors: Set<String> = ["with", "and", "plus", "topped", "made", "over", "of", "in", "on"]

    /// Generic state/marker words that don't change a food's identity — allowed in an
    /// "X, …, NFS" row when deciding whether it's the plain generic form of the query.
    static let genericMarkers: Set<String> = [
        "nfs", "ns", "as", "to", "type", "cooked", "raw", "brewed", "prepared",
        "reconstituted", "fresh", "or",
    ]

    /// Condiment/component words: a match that ADDS one of these (a "sauce",
    /// "dressing"…) the user didn't type, while missing part of their query, is a
    /// component standing in for a whole dish ("Alfredo sauce" for "fettuccine
    /// alfredo") — not a final answer. (Stemmed; "sauces" → "sauce".)
    static let componentWords: Set<String> = [
        "sauce", "dressing", "gravy", "marinade", "glaze", "vinaigrette",
        "seasoning", "condiment", "dip", "spread", "syrup",
    ]

    /// Portion/grammar words — never the food itself.
    static let fillerWords: Set<String> = [
        "a", "an", "the", "of", "with", "without", "and", "or", "some", "my", "in", "on",
        "bowl", "plate", "cup", "glass", "serving", "portion", "slice", "piece", "bit", "head", "block", "skewer",
        "large", "small", "medium", "big", "little", "half", "whole", "fresh", "plain",
        "made", "from", "homemade", "side",
        "couple", "few", "several", "pair", "bunch", "lots", "two", "three", "four", "five", "six",
        "g", "gram", "grams", "ml", "oz", "lb", "tbsp", "tsp", "scoop", "handful",
    ]

    // MARK: - Resource loading

    private static func loadBundled() -> [DBFood] {
        guard let url = Bundle.module.url(forResource: "FoodDB", withExtension: "json"),
              let data = try? Data(contentsOf: url) else {
            return []
        }
        return (try? JSONDecoder().decode([Row].self, from: data))?.map(\.food) ?? []
    }

    /// The compact on-disk schema (short keys keep the bundled file small).
    private struct Row: Decodable {
        let n: String
        let t: String
        let k, p, f, c: Double
        let fi, so, su: Double?
        let ps: [[PortionField]]?
        let r: [[IngredientField]]?

        var food: DBFood {
            DBFood(
                name: n, kind: t == "dish" ? .dish : .food,
                kcal: k, protein: p, fat: f, carbs: c, fiber: fi, sodium: so, sugar: su,
                portions: (ps ?? []).compactMap(Self.portion),
                recipe: (r ?? []).compactMap(Self.ingredient)
            )
        }

        static func portion(_ pair: [PortionField]) -> DBPortion? {
            guard pair.count == 2, case let .label(l) = pair[0], case let .number(g) = pair[1] else { return nil }
            return DBPortion(label: l, grams: g)
        }
        static func ingredient(_ pair: [IngredientField]) -> DBIngredient? {
            guard pair.count == 2, case let .label(n) = pair[0], case let .number(g) = pair[1] else { return nil }
            return DBIngredient(name: n, grams: g)
        }
    }

    /// Heterogeneous JSON tuples `["1 cup", 158]` decode as a string-or-number enum.
    private enum PortionField: Decodable {
        case label(String), number(Double)
        init(from decoder: Decoder) throws {
            let c = try decoder.singleValueContainer()
            if let s = try? c.decode(String.self) { self = .label(s) }
            else { self = .number(try c.decode(Double.self)) }
        }
    }
    private typealias IngredientField = PortionField
}
