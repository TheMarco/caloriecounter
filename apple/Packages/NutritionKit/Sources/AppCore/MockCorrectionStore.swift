// An in-memory FoodCorrectionStoring for unit tests, previews, and demo flows —
// no SwiftData, so FoodConfirmModel's pre-apply/remember logic can be driven
// deterministically. Seed it with corrections to simulate "you've edited this before".

import Foundation
import NutritionCore

public actor MockCorrectionStore: FoodCorrectionStoring {
    private var corrections: [String: FoodCorrection]

    public init(_ seed: [FoodCorrection] = []) {
        corrections = Dictionary(uniqueKeysWithValues: seed.map { ($0.key, $0) })
    }

    public func remember(_ correction: FoodCorrection) async {
        corrections[correction.key] = correction
    }

    public func correction(for key: String) async -> FoodCorrection? {
        corrections[key]
    }
}
