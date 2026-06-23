// CompositeBarcodeResolver: OpenFoodFacts first; on `.missingNutriments` (product
// known but no calorie data), fall back to the on-device FM estimator using the
// product name OFF surfaced. Proven with mocks — no network, no model.

import Testing
import Foundation
@testable import AppCore
import NutritionCore
import NutritionAPI

private struct MockResolver: BarcodeResolving {
    let result: Result<ParsedFood, Error>
    func resolve(code: String, units: UnitSystem) async throws -> ParsedFood {
        try result.get()
    }
}

/// Sendable recorder so the @Sendable estimator closure can report what it saw.
private actor Recorder {
    private(set) var name: String?
    private(set) var called = false
    func record(_ name: String) { self.name = name; self.called = true }
    func mark() { called = true }
}

@Suite("CompositeBarcodeResolver")
struct CompositeBarcodeResolverTests {

    private let off = ParsedFood(food: "Greek Yogurt", quantity: 100, unit: "g", kcal: 59)
    private let estimated = ParsedFood(food: "Cola", quantity: 1, unit: "serving", kcal: 140)

    @Test("returns the OpenFoodFacts result when nutriments are present")
    func primarySucceeds() async throws {
        let composite = CompositeBarcodeResolver(
            primary: MockResolver(result: .success(off)),
            estimate: { _, _ in Issue.record("estimator must not be called"); return self.estimated }
        )
        #expect(try await composite.resolve(code: "1", units: .metric) == off)
    }

    @Test("falls back to the estimator with the product name on .missingNutriments")
    func fallbackOnMissingNutriments() async throws {
        let recorder = Recorder()
        let estimated = self.estimated
        let composite = CompositeBarcodeResolver(
            primary: MockResolver(result: .failure(OpenFoodFactsError.missingNutriments(productName: "Cola"))),
            estimate: { name, _ in await recorder.record(name); return estimated }
        )
        let food = try await composite.resolve(code: "2", units: .metric)
        #expect(food == estimated)
        #expect(await recorder.name == "Cola")
    }

    @Test("rethrows .missingNutriments when no estimator is wired")
    func noEstimatorRethrows() async throws {
        let composite = CompositeBarcodeResolver(
            primary: MockResolver(result: .failure(OpenFoodFactsError.missingNutriments(productName: "X"))),
            estimate: nil
        )
        await #expect(throws: OpenFoodFactsError.self) {
            _ = try await composite.resolve(code: "3", units: .metric)
        }
    }

    @Test("a productNotFound error propagates unchanged (no fallback)")
    func productNotFoundPropagates() async throws {
        let recorder = Recorder()
        let estimated = self.estimated
        let composite = CompositeBarcodeResolver(
            primary: MockResolver(result: .failure(OpenFoodFactsError.productNotFound)),
            estimate: { _, _ in await recorder.mark(); return estimated }
        )
        await #expect(throws: OpenFoodFactsError.productNotFound) {
            _ = try await composite.resolve(code: "4", units: .metric)
        }
        #expect(await recorder.called == false)
    }
}
