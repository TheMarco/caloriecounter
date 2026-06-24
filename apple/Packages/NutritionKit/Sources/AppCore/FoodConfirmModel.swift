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

    // Editable ingredient breakdown for compound foods (a matched dish's recipe or
    // the model's itemization). Empty for simple foods. When present, the breakdown
    // is the SINGLE SOURCE OF TRUTH for the saved nutrition (Σ components × servings),
    // and the Advanced Nutrition fields are hidden in favor of it.
    public private(set) var components: [FoodComponent]
    /// Whether the breakdown disclosure is expanded (collapsed by default).
    public var componentsExpanded = false
    @ObservationIgnored private var userBreakdownEdited = false

    public let method: InputMethod
    @ObservationIgnored private let original: ParsedFood
    @ObservationIgnored private let store: any NutritionStoring

    public init(parsed: ParsedFood, method: InputMethod, store: any NutritionStoring) {
        self.original = parsed
        self.food = parsed.food
        self.unit = parsed.unit
        self.quantityText = FoodConfirmModel.format(parsed.quantity)
        self.components = parsed.components ?? []
        self.method = method
        self.store = store
    }

    public var quantity: Double { Double(quantityText) ?? 0 }
    /// True when this food carries an editable ingredient breakdown.
    public var hasBreakdown: Bool { !components.isEmpty }

    // Context nutrients are DERIVED like the macros: from the breakdown when present,
    // else scaled from the parse with the quantity. Read-only (nil stays unknown).
    public var fiber: Double? {
        hasBreakdown ? components.summed(\.fiber).map { round1($0 * quantityRatio) }
                     : original.fiber.map { round1($0 * quantityRatio) }
    }
    public var sodium: Double? {
        hasBreakdown ? components.summed(\.sodium).map { ($0 * quantityRatio).rounded() }
                     : original.sodium.map { ($0 * quantityRatio).rounded() }
    }
    public var sugar: Double? {
        hasBreakdown ? components.summed(\.sugar).map { round1($0 * quantityRatio) }
                     : original.sugar.map { round1($0 * quantityRatio) }
    }

    // MARK: - Breakdown editing (flips the source to .userEdited)

    /// Rescale one component to a new gram weight (its macros scale proportionally);
    /// the top-line nutrition recomputes from the breakdown.
    public func setComponentGrams(at index: Int, to grams: Double) {
        guard components.indices.contains(index), grams >= 0 else { return }
        components[index] = components[index].scaled(toGrams: grams)
        userBreakdownEdited = true
    }

    /// Drop a component (e.g. "no mayo"); the total drops by its contribution.
    public func removeComponent(at index: Int) {
        guard components.indices.contains(index) else { return }
        components.remove(at: index)
        userBreakdownEdited = true
    }

    /// Append a custom ingredient line.
    public func addComponent(_ component: FoodComponent) {
        components.append(component)
        userBreakdownEdited = true
    }

    private func componentSum(_ keyPath: KeyPath<FoodComponent, Double>) -> Double {
        components.reduce(0) { $0 + $1[keyPath: keyPath] }
    }
    private func round1(_ v: Double) -> Double { (v * 10).rounded() / 10 }
    /// How many "servings" the current amount is, relative to the original parse.
    private var quantityRatio: Double {
        guard original.quantity > 0 else { return amountInOriginalUnit }
        return amountInOriginalUnit / original.quantity
    }

    /// The current amount expressed in the ORIGINAL parse's unit, so nutrition is
    /// preserved across a compatible unit change (e.g. g↔oz). When the units
    /// aren't convertible (e.g. slice↔g) the raw amount is used (a relabel).
    private var amountInOriginalUnit: Double {
        UnitConversion.convert(quantity, from: unit, to: original.unit) ?? quantity
    }

    // MARK: - Derived nutrition (scales from the original parse with the quantity)

    /// Calories for the current amount, rounded. From the breakdown (Σ components ×
    /// servings) when present, else scaled from the original parse (web rule).
    public var kcal: Double {
        hasBreakdown ? (componentSum(\.kcal) * quantityRatio).rounded()
                     : MacroMath.recalculatedCalories(forQuantity: amountInOriginalUnit, originalKcal: original.kcal, originalQuantity: original.quantity)
    }
    public var fat: Double { hasBreakdown ? round1(componentSum(\.fat) * quantityRatio) : scaled(original.fat) }
    public var carbs: Double { hasBreakdown ? round1(componentSum(\.carbs) * quantityRatio) : scaled(original.carbs) }
    public var protein: Double { hasBreakdown ? round1(componentSum(\.protein) * quantityRatio) : scaled(original.protein) }

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
            method: method, confidence: original.confidence,
            fiber: fiber, sodium: sodium, sugar: sugar,
            nutritionConfidence: userBreakdownEdited ? .userEdited : original.nutritionConfidence
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
