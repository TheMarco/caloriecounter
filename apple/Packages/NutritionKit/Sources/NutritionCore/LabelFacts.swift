// LabelFacts — the five values read from a packaged food's Nutrition Facts panel,
// and VerifiedLabel — those values confirmed by the user and remembered for a
// specific barcode. The fullest expression of "more honest, more premium": once you
// verify a product against its own label, the app trusts that over a database guess
// and never re-asks. Pure value types; persistence lives behind BarcodeLabelStoring.

import Foundation

/// The per-serving figures lifted from a nutrition label. Deliberately just the five
/// fields the label flow captures (serving size + the four headline macros); context
/// nutrients are out of scope here.
public struct LabelFacts: Codable, Sendable, Equatable, Hashable {
    /// Human-readable serving, e.g. "1 cup (240 ml)" or "2 slices (56 g)".
    public var servingDescription: String
    public var kcal: Double
    public var protein: Double   // grams
    public var carbs: Double     // grams
    public var fat: Double       // grams

    public init(servingDescription: String, kcal: Double, protein: Double, carbs: Double, fat: Double) {
        self.servingDescription = servingDescription
        self.kcal = kcal
        self.protein = protein
        self.carbs = carbs
        self.fat = fat
    }
}

/// A product whose label the user has confirmed, keyed by its barcode. `name` lets
/// the app render the product without a fresh Open Food Facts round-trip.
public struct VerifiedLabel: Codable, Sendable, Equatable {
    public let barcode: String
    public var name: String
    public var facts: LabelFacts
    public var updatedAt: Date

    public init(barcode: String, name: String, facts: LabelFacts, updatedAt: Date) {
        self.barcode = barcode
        self.name = name
        self.facts = facts
        self.updatedAt = updatedAt
    }
}

/// Remembers and recalls user-verified labels by barcode. Backed by SwiftData in the
/// app, an in-memory mock in tests/demo — mirrors `FoodCorrectionStoring`.
public protocol BarcodeLabelStoring: Sendable {
    /// Upsert a verified label (replaces any prior one for the same barcode).
    func saveVerifiedLabel(_ label: VerifiedLabel) async
    /// The verified label for a barcode, or nil if the user hasn't verified it.
    func verifiedLabel(for barcode: String) async -> VerifiedLabel?
}
