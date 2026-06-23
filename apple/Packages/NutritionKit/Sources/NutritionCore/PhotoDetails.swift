// Portion context the user attaches to a plate photo, forwarded to the photo
// parser to sharpen the estimate. Ported from `PhotoCapture.tsx` (the plate-size
// and serving-type pickers, defaults 'medium' / 'home') and the prompt-side
// `sizeMap` / `typeMap` in `src/app/api/parse-photo/route.ts`.
//
// Raw values MUST match the web option strings (incl. the hyphenated
// "extra-large" / "fast-food") so the cloud `/api/parse-photo` proxy receives
// exactly what the web sends.

import Foundation

/// Plate/bowl size estimate (web `<select>` `value`s + prompt `sizeMap`).
public enum PlateSize: String, Codable, Sendable, CaseIterable {
    case small
    case medium
    case large
    case extraLarge = "extra-large"

    /// Picker label (web `<option>` text).
    public var label: String {
        switch self {
        case .small: return "Small plate/bowl"
        case .medium: return "Medium plate/bowl"
        case .large: return "Large plate/bowl"
        case .extraLarge: return "Extra large plate/bowl"
        }
    }

    /// Prompt context phrase (web `sizeMap` value) sent to the photo parser.
    public var promptDescription: String {
        switch self {
        case .small: return "small plate/bowl (about 6-8 inches)"
        case .medium: return "medium plate/bowl (about 9-10 inches)"
        case .large: return "large plate/bowl (about 11-12 inches)"
        case .extraLarge: return "extra large plate/bowl (about 13+ inches)"
        }
    }
}

/// Eating context (web serving-type `value`s + prompt `typeMap`).
public enum ServingType: String, Codable, Sendable, CaseIterable {
    case home
    case restaurant
    case fastFood = "fast-food"
    case snack

    /// Picker label.
    public var label: String {
        switch self {
        case .home: return "Home cooking"
        case .restaurant: return "Restaurant"
        case .fastFood: return "Fast food"
        case .snack: return "Snack"
        }
    }

    /// Prompt context phrase (web `typeMap` value).
    public var promptDescription: String {
        switch self {
        case .home: return "home cooking (typically smaller, more controlled portions)"
        case .restaurant: return "restaurant serving (typically larger portions)"
        case .fastFood: return "fast food serving (standardized portions)"
        case .snack: return "snack portion (smaller than meal portion)"
        }
    }
}

public struct PhotoDetails: Codable, Sendable, Equatable {
    public var plateSize: PlateSize
    public var servingType: ServingType
    /// Free-form hints (web `additionalDetails`, e.g. "half eaten", "shared between 2").
    public var additionalDetails: String

    public init(
        plateSize: PlateSize = .medium,
        servingType: ServingType = .home,
        additionalDetails: String = ""
    ) {
        self.plateSize = plateSize
        self.servingType = servingType
        self.additionalDetails = additionalDetails
    }

    /// Web defaults: medium plate, home cooking, no extra notes.
    public static let `default` = PhotoDetails()
}
