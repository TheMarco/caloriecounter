// Deterministic parse of OCR'd nutrition-panel text into a ParsedFood. Kept
// separate from VisionLabelReader so the regex logic is unit-testable without
// Vision. Anchors on a calorie value; "total fat"/"total carbohydrate" are
// preferred over their sub-rows (saturated fat, sugars).

import Foundation
import NutritionCore

public enum NutritionLabelParser {

    /// Parse recognized text lines. Returns nil when no calorie value is found
    /// (so the caller can fall back to a model interpretation).
    public static func parse(lines: [String]) -> ParsedFood? {
        let text = lines.joined(separator: "\n")
        guard let kcal = firstNumber(in: text, patterns: [#"calories[:\s]+(\d+(?:\.\d+)?)"#]) else {
            return nil
        }
        let fat = firstNumber(in: text, patterns: [
            #"total\s+fat[:\s]+(\d+(?:\.\d+)?)"#,
            #"(?<!saturated )(?<!trans )fat[:\s]+(\d+(?:\.\d+)?)"#,
            #"fat[:\s]+(\d+(?:\.\d+)?)"#,
        ]) ?? 0
        let carbs = firstNumber(in: text, patterns: [
            #"total\s+carb(?:ohydrate)?s?[:\s]+(\d+(?:\.\d+)?)"#,
            #"carb(?:ohydrate)?s?[:\s]+(\d+(?:\.\d+)?)"#,
        ]) ?? 0
        let protein = firstNumber(in: text, patterns: [#"protein[:\s]+(\d+(?:\.\d+)?)"#]) ?? 0
        // Context nutrients (optional — nil when the panel doesn't list them).
        let fiber = firstNumber(in: text, patterns: [
            #"dietary\s+fiber[:\s]+(\d+(?:\.\d+)?)"#,
            #"fiber[:\s]+(\d+(?:\.\d+)?)"#,
        ])
        let sodium = firstNumber(in: text, patterns: [#"sodium[:\s]+(\d+(?:\.\d+)?)"#])   // mg on US labels
        let sugar = firstNumber(in: text, patterns: [
            #"total\s+sugars[:\s]+(\d+(?:\.\d+)?)"#,
            #"sugars[:\s]+(\d+(?:\.\d+)?)"#,
        ])

        return ParsedFood(
            food: "Nutrition Label",
            quantity: 1, unit: "serving",
            kcal: kcal, fat: fat, carbs: carbs, protein: protein,
            notes: "Read from nutrition label - please verify",
            fiber: fiber, sodium: sodium, sugar: sugar,
            nutritionConfidence: .label
        )
    }

    /// First capture-group number matched by any pattern, in order.
    private static func firstNumber(in text: String, patterns: [String]) -> Double? {
        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { continue }
            let range = NSRange(text.startIndex..., in: text)
            guard let match = regex.firstMatch(in: text, range: range), match.numberOfRanges >= 2,
                  let r = Range(match.range(at: 1), in: text), let value = Double(text[r]) else { continue }
            return value
        }
        return nil
    }
}
