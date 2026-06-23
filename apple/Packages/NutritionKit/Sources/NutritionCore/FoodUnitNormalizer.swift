// Corrects awkward units the parser sometimes assigns to whole, handheld foods.
// A sandwich / burger / hot dog is naturally ONE "piece", but a model may tag it
// "slice" (bread association) or "g". This deterministic pass fixes the common
// cases so the user doesn't have to. Pure and unit-tested.

import Foundation

public enum FoodUnitNormalizer {
    /// Composite handheld foods that are counted as whole pieces, not sliced or
    /// weighed. (Pizza/bread/cake are intentionally absent — "slice" is right for
    /// them.)
    static let wholeItemKeywords = [
        "sandwich", "burger", "cheeseburger", "hamburger", "hot dog", "hotdog",
        "corn dog", "corndog", "taco", "burrito", "wrap", "hoagie", "sub sandwich",
        "panini", "quesadilla", "slider", "gyro", "kebab", "shawarma", "hot pocket",
        "calzone", "egg roll", "spring roll", "empanada", "dumpling", "bagel",
        "croissant", "muffin", "donut", "doughnut", "cupcake", "pancake", "waffle",
        "burrito bowl",
    ]

    /// Units we'll override toward "piece" for a whole item (the ones a model picks
    /// by mistake). "serving"/"plate"/"bowl" can be legitimate, so only override
    /// them for a single-item quantity.
    private static let overridableUnits: Set<String> = ["slice", "g", "oz", "serving", "bowl", "plate"]

    /// The natural unit for `food` given the parser's `unit`/`quantity`. Returns
    /// `unit` unchanged unless `food` is a recognized whole item that should be a
    /// "piece".
    public static func normalizedUnit(food: String, unit: String, quantity: Double) -> String {
        if unit == "piece" { return unit }
        let name = food.lowercased()
        guard wholeItemKeywords.contains(where: { name.contains($0) }) else { return unit }
        guard quantity <= 3, overridableUnits.contains(unit) else { return unit }
        return "piece"
    }
}
