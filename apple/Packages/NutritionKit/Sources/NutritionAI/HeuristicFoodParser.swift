// On-device fallback parser used when Foundation Models is unavailable (older
// device, Apple Intelligence off, model not ready). A faithful port of the
// `fallbackParsing` function in `src/app/api/parse-food/route.ts`:
//   1. "<number> <unit> <food>" regexes  → structural parse, no calorie estimate.
//   2. longest-key match over a common-portion table → estimated portion + kcal.
//   3. isDish-aware last resort defaults.
// Pure and deterministic, so it's fully unit-tested; the FoodParsing seam just
// wraps `estimate`.

import Foundation
import NutritionCore

public struct HeuristicFoodParser: FoodParsing {
    public init() {}

    public func parse(text: String, units: UnitSystem) async throws -> ParsedFood {
        Self.estimate(text, units: units)
    }

    // MARK: - Pure estimation

    public static func estimate(_ text: String, units: UnitSystem) -> ParsedFood {
        let clean = text.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)

        // 1. "<number> <unit> <food>"
        if let structural = quantityUnitMatch(clean) { return structural }

        // 2. Common-portion table, longest (most specific) key first.
        for (key, portion) in commonPortions.sorted(by: { $0.0.count > $1.0.count }) {
            if clean.contains(key) {
                return ParsedFood(food: key, quantity: portion.quantity, unit: portion.unit,
                                  kcal: portion.kcal, notes: "Estimated portion size - please verify")
            }
        }

        // 3. Last resort: dishes get a larger default portion than single items.
        let isDish = ["plate", "bowl", "dish", "serving", "portion"].contains { clean.contains($0) }
        return ParsedFood(
            food: clean,
            quantity: isDish ? 250 : 100,
            unit: "g",
            kcal: isDish ? 400 : 150,
            notes: "Estimated portion - please verify and adjust as needed"
        )
    }

    // MARK: - Quantity+unit regexes

    private struct UnitPattern { let words: String; let unit: String }
    private static let unitPatterns: [UnitPattern] = [
        .init(words: "g|gram|grams", unit: "g"),
        .init(words: "ml|milliliter|milliliters", unit: "ml"),
        .init(words: "cup|cups", unit: "cup"),
        .init(words: "tbsp|tablespoon|tablespoons", unit: "tbsp"),
        .init(words: "tsp|teaspoon|teaspoons", unit: "tsp"),
        .init(words: "piece|pieces", unit: "piece"),
        .init(words: "slice|slices", unit: "slice"),
    ]

    private static func quantityUnitMatch(_ clean: String) -> ParsedFood? {
        for pattern in unitPatterns {
            let regex = "^(\\d+)\\s*(?:\(pattern.words))\\s+(.+)$"
            guard let match = firstMatch(regex, in: clean), match.count == 3,
                  let qty = Double(match[1]) else { continue }
            let food = match[2].trimmingCharacters(in: .whitespaces)
            return ParsedFood(food: food, quantity: qty, unit: pattern.unit,
                              kcal: 0, notes: "Parsed without AI assistance")
        }
        return nil
    }

    /// Returns [fullMatch, group1, group2, …] for the first match, or nil.
    private static func firstMatch(_ pattern: String, in text: String) -> [String]? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return nil }
        let range = NSRange(text.startIndex..., in: text)
        guard let match = regex.firstMatch(in: text, range: range) else { return nil }
        return (0..<match.numberOfRanges).map { i in
            guard let r = Range(match.range(at: i), in: text) else { return "" }
            return String(text[r])
        }
    }

    // MARK: - Common-portion table (web `commonPortions`)

    private struct Portion { let quantity: Double; let unit: String; let kcal: Double }
    private static let commonPortions: [String: Portion] = [
        // Fruits
        "apple": .init(quantity: 150, unit: "g", kcal: 78),
        "banana": .init(quantity: 120, unit: "g", kcal: 107),
        "orange": .init(quantity: 130, unit: "g", kcal: 61),
        // Basic foods
        "egg": .init(quantity: 50, unit: "g", kcal: 70),
        "bread": .init(quantity: 30, unit: "g", kcal: 80),
        "slice of bread": .init(quantity: 30, unit: "g", kcal: 80),
        // Pasta dishes
        "pasta": .init(quantity: 300, unit: "g", kcal: 450),
        "spaghetti": .init(quantity: 300, unit: "g", kcal: 450),
        "fettuccine": .init(quantity: 300, unit: "g", kcal: 450),
        "fettuccine alfredo": .init(quantity: 350, unit: "g", kcal: 800),
        "plate of pasta": .init(quantity: 350, unit: "g", kcal: 500),
        "bowl of pasta": .init(quantity: 300, unit: "g", kcal: 450),
        // Rice dishes
        "rice": .init(quantity: 200, unit: "g", kcal: 260),
        "fried rice": .init(quantity: 250, unit: "g", kcal: 400),
        "plate of rice": .init(quantity: 200, unit: "g", kcal: 260),
        "bowl of rice": .init(quantity: 200, unit: "g", kcal: 260),
        // Meat portions
        "chicken": .init(quantity: 150, unit: "g", kcal: 248),
        "chicken breast": .init(quantity: 150, unit: "g", kcal: 248),
        "beef": .init(quantity: 150, unit: "g", kcal: 375),
        "pork": .init(quantity: 150, unit: "g", kcal: 390),
        // Common dishes
        "sandwich": .init(quantity: 1, unit: "piece", kcal: 350),
        "burger": .init(quantity: 1, unit: "piece", kcal: 540),
        "pizza slice": .init(quantity: 1, unit: "slice", kcal: 285),
        "slice of pizza": .init(quantity: 1, unit: "slice", kcal: 285),
    ]
}
