// On-device model instructions. The portion-size rules are ported verbatim from
// the OpenAI prompt in `src/app/api/parse-food/route.ts` so the local model
// estimates portions the same way the web app does (realistic servings, TOTAL —
// not per-100g — calories, unit preference by UnitSystem).

import Foundation
import NutritionCore

public enum Prompts {

    /// System instructions for parsing a free-text/voice food description into a
    /// `NutritionInfo`. `units` switches the measurement-unit guidance. `references`
    /// are USDA per-100g densities for foods that look like the user's input —
    /// injected as authoritative grounding so the model scales real numbers to a
    /// realistic portion instead of guessing the density.
    public static func foodInstructions(units: UnitSystem, references: [DBFood] = []) -> String {
        let unitsInstruction = units == .metric
            ? "The user prefers metric units. Use grams for solids and ml for liquids when possible (e.g., 44ml for a shot of tequila)."
            : "The user prefers imperial units. Use oz, lb, cups, tbsp, tsp as appropriate (e.g., 1.5oz for a shot of tequila)."

        return """
        You are a nutrition expert. Parse the user's food description into accurate \
        nutritional information for a realistic serving.

        \(unitsInstruction)

        CRITICAL PORTION SIZE RULES:
        - NEVER use unrealistic tiny portions (like 1g for a plate of food).
        - Pasta dishes: "plate/bowl of pasta" = 300-400g cooked pasta + sauce.
        - Rice dishes: "plate/bowl of rice" = 200-300g cooked rice + toppings.
        - Salads: "bowl/plate of salad" = 150-250g depending on ingredients.
        - Sandwiches/burgers: use the "piece" unit, total weight 150-300g.
        - Pizza: use the "slice" unit, a typical slice = 100-150g (~250-320 kcal).
        - Bread: a "slice of bread" is SMALL — 25-45g, ~70-130 kcal. A hearty/seeded
          sandwich loaf (e.g. Dave's Killer Bread) slice is ~110-130 kcal. NEVER
          estimate a bread slice like a pizza slice.
        - Soups: use the "bowl" unit, a typical serving = 250-300ml.
        - Meat portions: restaurant serving = 150-200g, home serving = 100-150g.

        UNIT SELECTION:
        - Whole handheld foods are ONE 'piece': sandwich, burger, hot dog, corn dog, \
        taco, burrito, wrap, quesadilla, egg, muffin, bagel. Never call these "slice".
        - Use 'slice' only for foods truly served in slices (pizza, bread, cake).
        - Use 'bowl'/'plate' for served meals, 'g'/'ml' for loose ingredients.

        IMPORTANT RULES:
        - For compound foods (e.g. "chili dog with cheese"), give the TOTAL for the \
        whole item, not per ingredient.
        - kcal is the TOTAL calories for the quantity specified, NOT per 100g.
        - Be generous with calorie estimates for restaurant/prepared foods.
        - Also estimate dietary fiber (grams), sodium (milligrams), and total sugars \
        (grams) for the serving. Round fiber and sugar to whole grams and sodium to \
        the nearest 50 mg — these are approximate, so don't imply false precision.

        REALISTIC PORTION EXAMPLES:
        - "plate of fettuccine alfredo" -> quantity 350, unit g, kcal ~800.
        - "bowl of chicken fried rice" -> quantity 300, unit g, kcal ~520.
        - "chili dog with cheese" -> quantity 1, unit piece, kcal ~550.
        - "slice of pepperoni pizza" -> quantity 1, unit slice, kcal ~298.
        - "slice of bread" -> quantity 1, unit slice, kcal ~80.
        - "slice of Dave's Killer Bread" -> quantity 1, unit slice, kcal ~120.
        - "2 eggs" -> quantity 2, unit piece, kcal ~140.
        \(referenceBlock(references))
        """
    }

    /// USDA per-100g grounding. When the retriever finds generic foods resembling
    /// the user's input, we list their REAL densities and tell the model to scale
    /// them to whatever realistic portion it decides — keeping its portion judgment
    /// while replacing guessed densities with measured ones. Empty when no match.
    static func referenceBlock(_ references: [DBFood]) -> String {
        guard !references.isEmpty else { return "" }
        let lines = references.map { f -> String in
            var parts = [
                "\(Int(f.kcal.rounded())) kcal",
                "\(fmt(f.protein))g protein",
                "\(fmt(f.fat))g fat",
                "\(fmt(f.carbs))g carbs",
            ]
            if let fi = f.fiber { parts.append("\(fmt(fi))g fiber") }
            if let su = f.sugar { parts.append("\(fmt(su))g sugar") }
            if let so = f.sodium { parts.append("\(Int(so.rounded()))mg sodium") }
            return "- \(f.name) (per 100g): \(parts.joined(separator: ", "))"
        }
        return """


        REFERENCE NUTRITION DATA (USDA, per 100 g) — authoritative densities for \
        generic foods similar to the user's input. If one clearly matches what the \
        user means, base your macros on its density and scale it to the realistic \
        serving size you choose (do NOT just copy the per-100g numbers unless the \
        serving really is 100 g). If none match, rely on your own knowledge.
        \(lines.joined(separator: "\n"))
        """
    }

    /// Trim trailing ".0" so "20.0" reads as "20" but "2.1" stays "2.1".
    private static func fmt(_ value: Double) -> String {
        value == value.rounded() ? String(Int(value)) : String(format: "%.1f", value)
    }

    /// System instructions for estimating nutrition from a barcode product name
    /// when OpenFoodFacts has no nutriments (fallback chain in AppCore).
    public static let barcodeInstructions = """
    You are a nutrition expert. Given a packaged product's name, identify the \
    product and estimate accurate nutritional information for ONE realistic \
    serving (use the typical single-serve size for that product type). Provide \
    the total calories and macros for that serving, not per 100g.
    """
}
