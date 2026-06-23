// The availability contract AppCore relies on to pick FM-vs-heuristic. We never
// invoke the model in tests (nondeterministic, needs on-device Apple
// Intelligence) — only the availability gate. On a host without Apple
// Intelligence (typical CI/dev Mac), the parsers must throw `.unavailable`
// rather than attempt a call; where it IS available, we just confirm the flag
// reads without crashing.

import Testing
@testable import NutritionAI
import NutritionCore

@Suite("Foundation Models availability gate")
struct FoundationModelsAvailabilityTests {

    @Test("isAvailable is readable and consistent across the FM types")
    func isAvailableReadable() {
        let available = FoundationModelsFoodParser.isAvailable
        #expect(FoundationModelsBarcodeEstimator.isAvailable == available)
    }

    @Test("when the model is unavailable, the food parser throws .unavailable (no call attempted)")
    func foodParserGuards() async throws {
        guard !FoundationModelsFoodParser.isAvailable else { return }   // skip where the model IS usable
        await #expect(throws: FoundationModelsError.unavailable) {
            _ = try await FoundationModelsFoodParser().parse(text: "apple", units: .metric)
        }
    }

    @Test("when the model is unavailable, the barcode estimator throws .unavailable")
    func barcodeEstimatorGuards() async throws {
        guard !FoundationModelsBarcodeEstimator.isAvailable else { return }
        await #expect(throws: FoundationModelsError.unavailable) {
            _ = try await FoundationModelsBarcodeEstimator().estimate(productName: "Cola", units: .metric)
        }
    }
}
