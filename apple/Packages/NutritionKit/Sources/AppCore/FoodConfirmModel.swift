// The shared confirm/edit model every capture flow converges on: an editable
// ParsedFood whose calories+macros are DERIVED from the current quantity (Core
// MacroMath rule, ported from EditEntryDialog.tsx), then saved as an Entry through
// the NutritionStoring seam. Lives in AppCore so the scaling and save logic is
// unit-tested independently of the SwiftUI sheet.
//
// Nutrition is computed (not stored) so it always tracks `quantityText` — reading
// `kcal`/`fat`/… in SwiftUI re-renders whenever the quantity changes, with no
// manual recalculation step to forget.

import Foundation
import Observation
import NutritionCore

@Observable
@MainActor
public final class FoodConfirmModel {
    public var food: String
    public var unit: String
    /// Edited as text so the field can be cleared; `quantity` parses it.
    public var quantityText: String

    public let method: InputMethod
    @ObservationIgnored private let original: ParsedFood
    @ObservationIgnored private let store: any NutritionStoring

    public init(parsed: ParsedFood, method: InputMethod, store: any NutritionStoring) {
        self.original = parsed
        self.food = parsed.food
        self.unit = parsed.unit
        self.quantityText = FoodConfirmModel.format(parsed.quantity)
        self.method = method
        self.store = store
    }

    public var quantity: Double { Double(quantityText) ?? 0 }

    /// The current amount expressed in the ORIGINAL parse's unit, so nutrition is
    /// preserved across a compatible unit change (e.g. g↔oz). When the units
    /// aren't convertible (e.g. slice↔g) the raw amount is used (a relabel).
    private var amountInOriginalUnit: Double {
        UnitConversion.convert(quantity, from: unit, to: original.unit) ?? quantity
    }

    // MARK: - Derived nutrition (scales from the original parse with the quantity)

    /// Calories for the current amount, rounded (web EditEntryDialog rule).
    public var kcal: Double {
        MacroMath.recalculatedCalories(forQuantity: amountInOriginalUnit, originalKcal: original.kcal, originalQuantity: original.quantity)
    }
    public var fat: Double { scaled(original.fat) }
    public var carbs: Double { scaled(original.carbs) }
    public var protein: Double { scaled(original.protein) }

    private func scaled(_ base: Double) -> Double {
        let amount = amountInOriginalUnit
        guard amount > 0, original.quantity > 0 else { return 0 }
        return base * (amount / original.quantity)
    }

    public func makeEntry(date: String = LocalDate.today(), now: Date = Date()) -> Entry {
        Entry(
            id: UUID().uuidString, date: date, timestamp: now,
            food: food.trimmingCharacters(in: .whitespacesAndNewlines),
            quantity: quantity, unit: unit,
            kcal: kcal, fat: fat, carbs: carbs, protein: protein,
            method: method, confidence: original.confidence
        )
    }

    @discardableResult
    public func save(date: String = LocalDate.today(), now: Date = Date()) async -> Entry {
        let entry = makeEntry(date: date, now: now)
        try? await store.add(entry)
        return entry
    }

    private static func format(_ value: Double) -> String {
        value == value.rounded() ? String(Int(value)) : String(value)
    }
}
