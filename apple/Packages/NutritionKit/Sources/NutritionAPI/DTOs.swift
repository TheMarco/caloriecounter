// Wire DTOs for the proxy endpoints and their mapping to/from the domain.
//
// `/api/auth`  ← AuthRequest{password}      → AuthResponse{success} (+ Set-Cookie)
// `/api/parse-photo` ← ParsePhotoRequest    → ParsePhotoResponse{success,data,error}
//
// The request `details` is the domain `PhotoDetails` verbatim: its Codable
// representation already emits the web-faithful keys/raw values
// (`plateSize:"extra-large"`, `servingType:"fast-food"`, `additionalDetails`)
// that `src/app/api/parse-photo/route.ts` reads.

import Foundation
import NutritionCore

public struct AuthRequest: Codable, Sendable {
    public let password: String
    public init(password: String) { self.password = password }
}

public struct AuthResponse: Codable, Sendable {
    public let success: Bool
}

public struct ParsePhotoRequest: Codable, Sendable {
    public let imageData: String      // base64 data URL ("data:image/jpeg;base64,…")
    public let units: String          // UnitSystem.rawValue ("metric"/"imperial")
    public let details: PhotoDetails?

    public init(imageData: String, units: String, details: PhotoDetails?) {
        self.imageData = imageData
        self.units = units
        self.details = details
    }
}

/// One ingredient line of a compound dish (mirrors `ParseFoodResponse.data.components`).
public struct ComponentDTO: Codable, Sendable {
    public let name: String
    public let grams: Double
    public let kcal: Double?
    public let fat: Double?
    public let carbs: Double?
    public let protein: Double?

    public func toDomain() -> FoodComponent {
        FoodComponent(name: name, grams: grams, kcal: (kcal ?? 0).rounded(),
                      fat: fat ?? 0, carbs: carbs ?? 0, protein: protein ?? 0)
    }
}

/// Mirrors `ParseFoodResponse.data` in `src/types/index.ts` (macros optional).
public struct ParsedFoodDTO: Codable, Sendable {
    public let food: String
    public let quantity: Double
    public let unit: String
    public let kcal: Double?
    public let fat: Double?
    public let carbs: Double?
    public let protein: Double?
    public let fiber: Double?
    public let sodium: Double?
    public let sugar: Double?
    public let notes: String?
    public let components: [ComponentDTO]?

    /// Missing macros default to 0 (web treats them as optional). Fiber/sodium/sugar
    /// stay nil when absent. A non-empty components list becomes the editable breakdown.
    public func toDomain() -> ParsedFood {
        let comps = components?.map { $0.toDomain() }
        return ParsedFood(
            food: food, quantity: quantity, unit: unit,
            kcal: kcal ?? 0, fat: fat ?? 0, carbs: carbs ?? 0, protein: protein ?? 0,
            confidence: nil, notes: notes,
            fiber: fiber, sodium: sodium, sugar: sugar,
            nutritionConfidence: .estimated,
            components: (comps?.isEmpty == false) ? comps : nil
        )
    }
}

/// `/api/parse-food` ← ParseFoodRequest{text, units} → ParseFoodResponse{success,data,error}.
public struct ParseFoodRequest: Codable, Sendable {
    public let text: String
    public let units: String        // UnitSystem.rawValue
    public init(text: String, units: String) {
        self.text = text
        self.units = units
    }
}

public struct ParseFoodResponse: Codable, Sendable {
    public let success: Bool
    public let data: ParsedFoodDTO?
    public let error: String?
}

public struct ParsePhotoResponse: Codable, Sendable {
    public let success: Bool
    public let data: ParsedFoodDTO?
    public let error: String?
}
