// The outermost barcode resolver: if the user has already verified this product
// against its label, return those trusted local values immediately (so a re-scan
// shows "Label verified" and skips the network). Otherwise delegate to the normal
// chain (OpenFoodFacts → cloud estimate). This is what makes verification "stick".

import Foundation
import NutritionCore

public struct VerifiedLabelBarcodeResolver: BarcodeResolving {
    private let labels: any BarcodeLabelStoring
    private let fallback: any BarcodeResolving

    public init(labels: any BarcodeLabelStoring, fallback: any BarcodeResolving) {
        self.labels = labels
        self.fallback = fallback
    }

    public func resolve(code: String, units: UnitSystem) async throws -> ParsedFood {
        if let verified = await labels.verifiedLabel(for: code) {
            return Self.parsedFood(from: verified)
        }
        return try await fallback.resolve(code: code, units: units)
    }

    /// Build a confirm-ready ParsedFood from a stored verified label: one serving,
    /// the user's trusted numbers, flagged label-verified.
    static func parsedFood(from label: VerifiedLabel) -> ParsedFood {
        ParsedFood(
            food: label.name,
            quantity: 1,
            unit: "serving",
            kcal: label.facts.kcal,
            fat: label.facts.fat,
            carbs: label.facts.carbs,
            protein: label.facts.protein,
            notes: "Per serving: \(label.facts.servingDescription)",
            nutritionConfidence: .label,
            barcode: label.barcode,
            labelVerified: true
        )
    }
}
