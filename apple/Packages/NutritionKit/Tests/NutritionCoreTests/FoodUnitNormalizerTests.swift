// FoodUnitNormalizer: whole handheld foods become "piece"; everything else is
// left alone.

import Testing
@testable import NutritionCore

@Suite("FoodUnitNormalizer")
struct FoodUnitNormalizerTests {

    @Test("whole handheld foods tagged with an awkward unit become piece")
    func wholeItemsBecomePiece() {
        #expect(FoodUnitNormalizer.normalizedUnit(food: "Peanut Butter and Jelly Sandwich", unit: "slice", quantity: 1) == "piece")
        #expect(FoodUnitNormalizer.normalizedUnit(food: "Hot Dog", unit: "g", quantity: 1) == "piece")
        #expect(FoodUnitNormalizer.normalizedUnit(food: "Corn Dog", unit: "serving", quantity: 1) == "piece")
        #expect(FoodUnitNormalizer.normalizedUnit(food: "Cheeseburger", unit: "slice", quantity: 1) == "piece")
        #expect(FoodUnitNormalizer.normalizedUnit(food: "Chicken Burrito", unit: "g", quantity: 2) == "piece")
    }

    @Test("already-piece and legitimately non-whole foods are unchanged")
    func leavesOthersAlone() {
        // Pizza/bread genuinely use slice.
        #expect(FoodUnitNormalizer.normalizedUnit(food: "Pepperoni Pizza", unit: "slice", quantity: 1) == "slice")
        #expect(FoodUnitNormalizer.normalizedUnit(food: "Sourdough Bread", unit: "slice", quantity: 2) == "slice")
        // Loose ingredients stay weighed.
        #expect(FoodUnitNormalizer.normalizedUnit(food: "Brown Rice", unit: "g", quantity: 200) == "g")
        // A whole item already counted in pieces is left as-is.
        #expect(FoodUnitNormalizer.normalizedUnit(food: "Sandwich", unit: "piece", quantity: 1) == "piece")
    }

    @Test("a large weighed quantity of a whole-item name isn't force-changed")
    func bigQuantityNotOverridden() {
        // "500 g of burger meat" shouldn't become 500 pieces.
        #expect(FoodUnitNormalizer.normalizedUnit(food: "Burger Patty", unit: "g", quantity: 500) == "g")
    }
}
