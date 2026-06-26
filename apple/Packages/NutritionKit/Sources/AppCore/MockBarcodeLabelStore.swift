// An in-memory BarcodeLabelStoring for unit tests, previews, and demo flows — no
// SwiftData, so the verify-with-label flow can be driven deterministically. Seed it
// with verified labels to simulate "you've already verified this product".

import Foundation
import NutritionCore

public actor MockBarcodeLabelStore: BarcodeLabelStoring {
    private var labels: [String: VerifiedLabel]

    public init(_ seed: [VerifiedLabel] = []) {
        labels = Dictionary(uniqueKeysWithValues: seed.map { ($0.barcode, $0) })
    }

    public func saveVerifiedLabel(_ label: VerifiedLabel) async {
        labels[label.barcode] = label
    }

    public func verifiedLabel(for barcode: String) async -> VerifiedLabel? {
        labels[barcode]
    }
}
