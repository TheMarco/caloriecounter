// ConfidenceDisplay: the pure mapping from a NutritionConfidence source to the
// three user-facing provenance badges — Measured / Estimated / Adjusted — plus
// their SF Symbol and exactness. Kept here (not in the SwiftUI view) so the
// honesty rule is unit-tested and shared by every surface that shows a badge.

import Testing
@testable import NutritionCore

@Suite("ConfidenceDisplay")
struct ConfidenceDisplayTests {

    @Test("label and barcode are Measured and exact")
    func measuredSources() {
        for source in [NutritionConfidence.label, .barcode] {
            let d = ConfidenceDisplay.from(source)
            #expect(d.kind == .measured)
            #expect(d.title == "Measured")
            #expect(d.isExact)
            #expect(d.symbolName == "checkmark.seal")
        }
    }

    @Test("userEdited is Adjusted and exact")
    func adjustedSource() {
        let d = ConfidenceDisplay.from(.userEdited)
        #expect(d.kind == .adjusted)
        #expect(d.title == "Adjusted")
        #expect(d.isExact)
        #expect(d.symbolName == "pencil.and.outline")
    }

    @Test("estimated and unknown are Estimated and not exact")
    func estimatedSources() {
        for source in [NutritionConfidence.estimated, .unknown] {
            let d = ConfidenceDisplay.from(source)
            #expect(d.kind == .estimated)
            #expect(d.title == "Estimated")
            #expect(!d.isExact)
            #expect(d.symbolName == "sparkles")
        }
    }

    @Test("nil (no recorded source) is treated as Estimated, not exact")
    func nilIsEstimated() {
        let d = ConfidenceDisplay.from(nil)
        #expect(d.kind == .estimated)
        #expect(d.title == "Estimated")
        #expect(!d.isExact)
    }

    @Test("exactness agrees with the underlying NutritionConfidence.isExact")
    func exactnessMatchesSource() {
        for source in NutritionConfidence.allCases {
            #expect(ConfidenceDisplay.from(source).isExact == source.isExact)
        }
    }
}
