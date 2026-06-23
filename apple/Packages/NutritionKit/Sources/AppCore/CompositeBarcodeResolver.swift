// Barcode resolution chain: OpenFoodFacts first; if the product is known but has
// no calorie data (`OpenFoodFactsError.missingNutriments`), fall back to an
// on-device estimate from the product name. The estimator is injected as a
// closure so AppCore can wire FoundationModelsBarcodeEstimator while tests pass a
// mock (and so this layer doesn't hard-depend on NutritionAI).

import Foundation
import NutritionCore
import NutritionAPI

public struct CompositeBarcodeResolver: BarcodeResolving {
    public typealias Estimator = @Sendable (_ productName: String, _ units: UnitSystem) async throws -> ParsedFood

    private let primary: any BarcodeResolving
    private let estimate: Estimator?

    public init(primary: any BarcodeResolving, estimate: Estimator?) {
        self.primary = primary
        self.estimate = estimate
    }

    public func resolve(code: String, units: UnitSystem) async throws -> ParsedFood {
        do {
            return try await primary.resolve(code: code, units: units)
        } catch let OpenFoodFactsError.missingNutriments(productName) {
            guard let estimate else {
                throw OpenFoodFactsError.missingNutriments(productName: productName)
            }
            return try await estimate(productName, units)
        }
    }
}
