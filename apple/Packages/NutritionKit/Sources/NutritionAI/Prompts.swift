// On-device model instructions. The portion-size rules are ported verbatim from
// the OpenAI prompt in `src/app/api/parse-food/route.ts` so the local model
// estimates portions the same way the web app does (realistic servings, TOTAL —
// not per-100g — calories, unit preference by UnitSystem).

import Foundation
import NutritionCore

public enum Prompts {

    /// System instructions for parsing a free-text/voice food description into a
    /// `NutritionInfo`. `units` switches the measurement-unit guidance.
    public static func foodInstructions(units: UnitSystem) -> String {
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
        - Pizza: use the "slice" unit, a typical slice = 100-150g.
        - Soups: use the "bowl" unit, a typical serving = 250-300ml.
        - Meat portions: restaurant serving = 150-200g, home serving = 100-150g.

        IMPORTANT RULES:
        - For compound foods (e.g. "chili dog with cheese"), give the TOTAL for the \
        whole item, not per ingredient.
        - kcal is the TOTAL calories for the quantity specified, NOT per 100g.
        - Be generous with calorie estimates for restaurant/prepared foods.

        REALISTIC PORTION EXAMPLES:
        - "plate of fettuccine alfredo" -> quantity 350, unit g, kcal ~800.
        - "bowl of chicken fried rice" -> quantity 300, unit g, kcal ~520.
        - "chili dog with cheese" -> quantity 1, unit piece, kcal ~550.
        - "slice of pepperoni pizza" -> quantity 1, unit slice, kcal ~298.
        - "2 eggs" -> quantity 2, unit piece, kcal ~140.
        """
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
