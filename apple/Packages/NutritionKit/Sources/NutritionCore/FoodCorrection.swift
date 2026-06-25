// FoodCorrection — the app's memory of *your* numbers for a food.
//
// The fullest expression of the honesty north star: when you edit an estimate, the
// app remembers your correction keyed by normalized food name + unit, and pre-
// applies it next time so it stops re-guessing what you've already told it. A pure
// value type; persistence lives behind the FoodCorrectionStoring seam.

import Foundation

public struct FoodCorrection: Codable, Sendable, Equatable {
    /// Normalized food+unit identity (see `key(food:unit:)`).
    public let key: String
    public var kcal: Double
    public var fat: Double
    public var carbs: Double
    public var protein: Double
    public var fiber: Double?
    public var sodium: Double?
    public var sugar: Double?
    public var updatedAt: Date

    public init(
        key: String,
        kcal: Double, fat: Double, carbs: Double, protein: Double,
        fiber: Double? = nil, sodium: Double? = nil, sugar: Double? = nil,
        updatedAt: Date
    ) {
        self.key = key
        self.kcal = kcal; self.fat = fat; self.carbs = carbs; self.protein = protein
        self.fiber = fiber; self.sodium = sodium; self.sugar = sugar
        self.updatedAt = updatedAt
    }

    /// Convenience initializer that derives the key from the food name + unit.
    public init(
        food: String, unit: String,
        kcal: Double, fat: Double, carbs: Double, protein: Double,
        fiber: Double? = nil, sodium: Double? = nil, sugar: Double? = nil,
        updatedAt: Date
    ) {
        self.init(key: Self.key(food: food, unit: unit),
                  kcal: kcal, fat: fat, carbs: carbs, protein: protein,
                  fiber: fiber, sodium: sodium, sugar: sugar, updatedAt: updatedAt)
    }

    /// Normalize a food name + unit into a stable lookup key (lowercased, trimmed,
    /// inner whitespace collapsed) so re-logging the same food — however it's typed —
    /// finds the prior correction.
    public static func key(food: String, unit: String) -> String {
        "\(normalize(food))|\(normalize(unit))"
    }

    private static func normalize(_ s: String) -> String {
        s.lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
    }
}

/// Remembers and recalls per-food corrections. Backed by SwiftData in the app, an
/// in-memory mock in tests/demo.
public protocol FoodCorrectionStoring: Sendable {
    /// Upsert a correction (replaces any prior one for the same key).
    func remember(_ correction: FoodCorrection) async
    /// The remembered correction for a key, or nil if none.
    func correction(for key: String) async -> FoodCorrection?
}
