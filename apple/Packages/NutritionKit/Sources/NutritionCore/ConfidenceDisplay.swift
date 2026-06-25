// ConfidenceDisplay — the pure mapping from a recorded NutritionConfidence to the
// three provenance badges the user actually sees. We never extend the
// NutritionConfidence enum (it models *where numbers came from*); this collapses
// those sources into the honest, human-facing distinction:
//
//   .label, .barcode      → "Measured"  (exact — precise label/database numbers)
//   .userEdited           → "Adjusted"  (exact — your own correction)
//   .estimated, .unknown  → "Estimated" (a guess — shown rounded, "about N")
//   nil (nothing recorded)→ "Estimated" (assume the cautious, honest framing)
//
// SwiftUI-free so the rule is unit-tested and shared by every badge surface; the
// view layer maps `kind`/`symbolName` to a tint color.

import Foundation

public struct ConfidenceDisplay: Equatable, Sendable {

    public enum Kind: Equatable, Sendable {
        case measured   // exact, from a label or product database
        case adjusted   // exact, the user's own corrected numbers
        case estimated  // a guess — round it, frame it as "about"
    }

    public let kind: Kind
    /// The badge title: "Measured" / "Adjusted" / "Estimated".
    public let title: String
    /// SF Symbol name for the badge.
    public let symbolName: String
    /// Whether the underlying numbers should be shown precisely (vs. rounded "about N").
    public let isExact: Bool

    public static func from(_ confidence: NutritionConfidence?) -> ConfidenceDisplay {
        switch confidence {
        case .label, .barcode:
            return ConfidenceDisplay(kind: .measured, title: "Measured",
                                     symbolName: "checkmark.seal", isExact: true)
        case .userEdited:
            return ConfidenceDisplay(kind: .adjusted, title: "Adjusted",
                                     symbolName: "pencil.and.outline", isExact: true)
        case .estimated, .unknown, .none:
            return ConfidenceDisplay(kind: .estimated, title: "Estimated",
                                     symbolName: "sparkles", isExact: false)
        }
    }
}
