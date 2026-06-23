// Where an entry's nutrition numbers came from — so the UI can avoid presenting
// AI-estimated fiber/sodium as if they were exact label values.

import Foundation

public enum NutritionConfidence: String, Codable, Sendable, CaseIterable {
    case label        // read from a nutrition label (OCR)
    case barcode      // a product database (OpenFoodFacts)
    case userEdited   // the user typed/corrected it
    case estimated    // an AI/heuristic estimate
    case unknown

    /// Whether values from this source should be treated as exact (vs. an estimate
    /// to round). Label/barcode/user-edited are exact; estimates are not.
    public var isExact: Bool {
        switch self {
        case .label, .barcode, .userEdited: return true
        case .estimated, .unknown: return false
        }
    }
}
