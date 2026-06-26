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
    @ObservationIgnored private var original: ParsedFood
    @ObservationIgnored private let store: any NutritionStoring
    @ObservationIgnored private let corrections: (any FoodCorrectionStoring)?
    @ObservationIgnored private let barcodeLabels: (any BarcodeLabelStoring)?

    /// The scanned barcode this food came from (nil unless it's a barcode result) —
    /// the key under which a verified label is remembered.
    public let barcode: String?
    /// Whether the current values are trusted, user-confirmed label values for this
    /// barcode. Drives the "Label verified" badge.
    public private(set) var labelVerified: Bool

    /// True once a remembered per-food correction has been pre-applied — the view
    /// surfaces a subtle "we remembered your last edit" note.
    public private(set) var appliedRememberedCorrection = false

    public init(parsed: ParsedFood, method: InputMethod, store: any NutritionStoring,
                corrections: (any FoodCorrectionStoring)? = nil,
                barcodeLabels: (any BarcodeLabelStoring)? = nil) {
        self.original = parsed
        self.food = parsed.food
        self.unit = parsed.unit
        self.quantityText = FoodConfirmModel.format(parsed.quantity)
        self.components = parsed.components ?? []
        self.method = method
        self.store = store
        self.corrections = corrections
        self.barcodeLabels = barcodeLabels
        self.barcode = parsed.barcode
        self.labelVerified = parsed.labelVerified
    }

    public var quantity: Double { Double(quantityText) ?? 0 }
    /// True when this food carries an editable ingredient breakdown.
    public var hasBreakdown: Bool { !components.isEmpty }

    // Context nutrients are DERIVED like the macros: from the breakdown when its
    // components carry them, else from the parse's own value (cloud components only
    // carry kcal+macros, so fiber/sodium/sugar come from the serving total). Scaled
    // by the quantity. Read-only (nil stays unknown).
    public var fiber: Double? {
        ((hasBreakdown ? components.summed(\.fiber) : nil) ?? original.fiber).map { round1($0 * quantityRatio) }
    }
    public var sodium: Double? {
        ((hasBreakdown ? components.summed(\.sodium) : nil) ?? original.sodium).map { ($0 * quantityRatio).rounded() }
    }
    public var sugar: Double? {
        ((hasBreakdown ? components.summed(\.sugar) : nil) ?? original.sugar).map { round1($0 * quantityRatio) }
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

    // MARK: - Confirm-screen correction chips (½ · 2× · Less · More · Swap unit)

    /// The amount the original parse described — the basis for the ½ / 2× chips, so
    /// "½" always means half of the parsed serving (not half of the current amount).
    public var basePortion: Double { original.quantity }

    /// Set the amount to a multiple of the original serving (½ → 0.5, 2× → 2).
    public func setPortion(_ multiplier: Double) {
        guard basePortion > 0 else { return }
        quantityText = Self.format(basePortion * multiplier)
    }

    /// Whether the current amount equals the given multiple of the base serving
    /// (drives the chip's selected state).
    public func isPortion(_ multiplier: Double) -> Bool {
        guard basePortion > 0 else { return false }
        return abs(quantity - basePortion * multiplier) < 0.05
    }

    /// Nudge the amount by a factor (Less ≈ 0.85, More ≈ 1.15), re-rounded to a tidy
    /// step so it never lands on a fussy decimal.
    public func nudge(_ factor: Double) {
        quantityText = Self.format(Self.tidyRound(quantity * factor))
    }

    /// Cycle to the next compatible unit, converting the amount so the nutrition is
    /// preserved (g↔oz↔lb, ml↔cup↔…). A no-op for abstract units with no family.
    public func cycleUnit() {
        let units = UnitConversion.compatibleUnits(with: unit)
        guard units.count > 1, let i = units.firstIndex(of: unit) else { return }
        let next = units[(i + 1) % units.count]
        if let converted = UnitConversion.convert(quantity, from: unit, to: next) {
            quantityText = Self.format(round2(converted))
        }
        unit = next
    }

    /// The provenance to surface on the confirm badge: a hand-edited breakdown reads
    /// as "Adjusted" (.userEdited); otherwise it's whatever the parse reported.
    public var nutritionConfidence: NutritionConfidence? {
        userBreakdownEdited ? .userEdited : original.nutritionConfidence
    }
    /// Whether the current numbers should be shown precisely (vs. rounded "about N").
    public var isExact: Bool { nutritionConfidence?.isExact ?? false }

    /// A shaky estimate the UI should acknowledge with a softer (uncertain) haptic
    /// rather than a confident one.
    public var isLowConfidenceEstimate: Bool {
        nutritionConfidence == .estimated && (original.confidence ?? 1) < 0.5
    }

    // MARK: - Verify with label (packaged-food trust)

    /// A barcode result the user can verify against its printed label — offered as a
    /// small action on every (not-yet-verified) barcode result.
    public var canVerifyWithLabel: Bool {
        method == .barcode && barcode != nil && !labelVerified
    }

    /// A barcode whose database lookup was only an estimate (Open Food Facts knew the
    /// product but had no nutrition). For these we promote label scanning as the
    /// PRIMARY action — but never block a plain Add.
    public var isLowConfidenceBarcode: Bool {
        canVerifyWithLabel && original.nutritionConfidence == .estimated
    }

    /// Adopt user-confirmed label values: remember them for this barcode (so the next
    /// scan is pre-verified) and replace the working values with the label's
    /// (one serving, trusted, flagged label-verified). Called from the comparison
    /// screen's "Use label values".
    public func applyLabel(_ facts: LabelFacts, now: Date = Date()) async {
        let name = food.trimmingCharacters(in: .whitespacesAndNewlines)
        if let code = barcode {
            await barcodeLabels?.saveVerifiedLabel(
                VerifiedLabel(barcode: code, name: name, facts: facts, updatedAt: now)
            )
        }
        original = ParsedFood(
            food: name, quantity: 1, unit: "serving",
            kcal: facts.kcal, fat: facts.fat, carbs: facts.carbs, protein: facts.protein,
            notes: "Per serving: \(facts.servingDescription)",
            nutritionConfidence: .label,
            barcode: barcode, labelVerified: true
        )
        food = name
        unit = "serving"
        quantityText = "1"
        components = []
        userBreakdownEdited = false
        labelVerified = true
    }

    private func round2(_ v: Double) -> Double { (v * 100).rounded() / 100 }
    /// Round to a tidy step scaled to the amount's magnitude (nearest 5 for big
    /// amounts, 1 for medium, 0.5 for small) so a ±15% nudge reads cleanly.
    private static func tidyRound(_ v: Double) -> Double {
        let step: Double = v >= 40 ? 5 : (v >= 8 ? 1 : 0.5)
        return (v / step).rounded() * step
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

    // MARK: - Per-food correction memory (the app learns your truth)

    /// If this is an *estimate* and we remember a prior correction for this exact
    /// food+unit, pre-apply your remembered numbers and mark it Adjusted. Measured
    /// sources (label/barcode) are trusted and never overwritten. Async — call from
    /// the `.task` that builds the model. Idempotent.
    public func loadRememberedCorrection() async {
        guard !appliedRememberedCorrection else { return }
        guard !(original.nutritionConfidence?.isExact ?? false) else { return }   // don't override measured
        guard let corrections else { return }
        let key = FoodCorrection.key(food: original.food, unit: original.unit)
        guard let c = await corrections.correction(for: key) else { return }
        // The remembered numbers are per-unit; rebuild the basis at the parsed
        // quantity so the usual quantity scaling keeps working, and drop any stale
        // breakdown — your correction is the truth now.
        let q = original.quantity
        original = ParsedFood(
            food: original.food, quantity: q, unit: original.unit,
            kcal: c.kcal * q, fat: c.fat * q, carbs: c.carbs * q, protein: c.protein * q,
            confidence: original.confidence, notes: original.notes,
            fiber: c.fiber.map { $0 * q }, sodium: c.sodium.map { $0 * q }, sugar: c.sugar.map { $0 * q },
            nutritionConfidence: .userEdited, components: nil
        )
        components = []
        appliedRememberedCorrection = true
    }

    /// The user's edited numbers as a per-unit correction to remember.
    private func perUnitCorrection(from e: Entry, at now: Date) -> FoodCorrection {
        let q = e.quantity
        func per(_ v: Double) -> Double { q > 0 ? v / q : v }
        func perOpt(_ v: Double?) -> Double? { v.map { q > 0 ? $0 / q : $0 } }
        return FoodCorrection(
            food: e.food, unit: e.unit,
            kcal: per(e.kcal), fat: per(e.fat), carbs: per(e.carbs), protein: per(e.protein),
            fiber: perOpt(e.fiber), sodium: perOpt(e.sodium), sugar: perOpt(e.sugar),
            updatedAt: now
        )
    }

    @discardableResult
    public func save(date: String = LocalDate.today(), now: Date = Date()) async -> Entry {
        let entry = makeEntry(date: date, now: now)
        try? await store.add(entry)
        // Remember the correction when the user actually changed the numbers (edited
        // the breakdown), so re-logging this food pre-applies their truth.
        if userBreakdownEdited, entry.quantity > 0 {
            await corrections?.remember(perUnitCorrection(from: entry, at: now))
        }
        return entry
    }

    private static func format(_ value: Double) -> String {
        value == value.rounded() ? String(Int(value)) : String(value)
    }
}
