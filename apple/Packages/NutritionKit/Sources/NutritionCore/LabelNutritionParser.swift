// LabelNutritionParser — turns the raw lines Apple's Vision OCR reads off a Nutrition
// Facts panel into structured LabelFacts (serving size + calories/protein/carbs/fat).
//
// Pure and synchronous so it's fully unit-testable and runs on-device with no
// network. Nutrition Facts panels are highly standardized, so this is regex over a
// flattened blob: tolerant of OCR quirks (the panel may arrive as one line or many,
// with "0mg"/"0 g"/colons/extra words). The comparison screen is the safety net for
// anything it reads wrong, so it errs toward extracting a value rather than nothing.

import Foundation

public enum LabelNutritionParser {

    /// Parse OCR'd label lines. Returns nil only when no calories AND no macros could
    /// be found at all (i.e. this clearly wasn't a nutrition label). A missing single
    /// field defaults to 0 — the user verifies on the comparison screen.
    public static func parse(lines: [String]) -> LabelFacts? {
        // Flatten to one lowercased blob; OCR splits the panel unpredictably.
        let blob = lines.joined(separator: "\n").lowercased()

        let kcal = calories(in: blob)
        let protein = grams(for: ["protein"], in: blob)
        // "total carbohydrate" / "carbohydrate" / "carbs"
        let carbs = grams(for: ["total carbohydrate", "carbohydrate", "carbs", "carbohydrates"], in: blob)
        let fat = grams(for: ["total fat", "fat"], in: blob)

        // If we found nothing quantitative, this wasn't a label we can use.
        guard kcal != nil || protein != nil || carbs != nil || fat != nil else { return nil }

        return LabelFacts(
            servingDescription: servingSize(in: blob) ?? "1 serving",
            kcal: kcal ?? 0,
            protein: protein ?? 0,
            carbs: carbs ?? 0,
            fat: fat ?? 0
        )
    }

    // MARK: - Field extractors

    /// "Calories 240" / "Calories: 240" / "Calories\n240" / "240 calories".
    static func calories(in blob: String) -> Double? {
        // Prefer a number that follows the word "calories".
        if let v = firstNumber(matching: #"calories[^0-9]{0,12}([0-9]{1,4})"#, in: blob) { return v }
        // Fallback: a number immediately before "calories".
        if let v = firstNumber(matching: #"([0-9]{1,4})\s*calories"#, in: blob) { return v }
        return nil
    }

    /// A gram value for the first matching nutrient label, e.g. "Total Fat 8g",
    /// "Protein 12 g", "Total Carbohydrate: 30g". Tries each alias in order.
    static func grams(for aliases: [String], in blob: String) -> Double? {
        for alias in aliases {
            let escaped = NSRegularExpression.escapedPattern(for: alias)
            // <alias> ... <number> g   (allow OCR noise / colon / "less than" between)
            if let v = firstNumber(matching: "\(escaped)[^0-9]{0,12}([0-9]+(?:\\.[0-9]+)?)\\s*g", in: blob) {
                return v
            }
        }
        return nil
    }

    /// "Serving size 1 cup (240ml)" / "Serving Size: 2 slices (56 g)".
    static func servingSize(in blob: String) -> String? {
        guard let range = blob.range(of: #"serving size[ :]+"#, options: .regularExpression) else { return nil }
        // Take the remainder of that line as the serving description.
        let after = blob[range.upperBound...]
        let line = after.prefix(while: { $0 != "\n" })
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }
        return cleanedServing(trimmed)
    }

    // MARK: - Helpers

    /// First capture group of `pattern` parsed as a Double, searching the whole blob.
    private static func firstNumber(matching pattern: String, in blob: String) -> Double? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return nil }
        let range = NSRange(blob.startIndex..<blob.endIndex, in: blob)
        guard let match = regex.firstMatch(in: blob, options: [], range: range), match.numberOfRanges > 1,
              let r = Range(match.range(at: 1), in: blob) else { return nil }
        return Double(blob[r])
    }

    /// Title-case a serving description and collapse whitespace for display.
    private static func cleanedServing(_ s: String) -> String {
        let collapsed = s.split(whereSeparator: \.isWhitespace).joined(separator: " ")
        return collapsed.prefix(1).uppercased() + collapsed.dropFirst()
    }
}
