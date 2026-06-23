// On-device nutrition estimate from a product name, used by AppCore's barcode
// chain when OpenFoodFacts has the product but no nutriments
// (OpenFoodFactsError.missingNutriments). Foundation Models only — no network.

import Foundation
import FoundationModels
import NutritionCore

public struct FoundationModelsBarcodeEstimator: Sendable {
    public init() {}

    public static var isAvailable: Bool { FoundationModelsFoodParser.isAvailable }

    public func estimate(productName: String, units: UnitSystem) async throws -> ParsedFood {
        guard Self.isAvailable else { throw FoundationModelsError.unavailable }
        let session = LanguageModelSession(instructions: Prompts.barcodeInstructions)
        let response = try await session.respond(
            to: "Product: \(productName). Preferred units: \(units.rawValue).",
            generating: NutritionInfo.self
        )
        return response.content.toParsedFood()
    }
}
