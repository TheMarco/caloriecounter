// FoodParsing via on-device Foundation Models (Apple Intelligence). Text/voice
// descriptions are parsed into a guided `NutritionInfo` and mapped to ParsedFood.
// No network, no API key — fully private/offline.
//
// AppCore (Phase 5) checks `isAvailable` at wiring time and falls back to
// `HeuristicFoodParser` when the model isn't usable; this type also guards each
// call defensively and throws `.unavailable` so a late state change is handled.

import Foundation
import FoundationModels
import NutritionCore

public enum FoundationModelsError: Error, Sendable, Equatable {
    case unavailable
}

public struct FoundationModelsFoodParser: FoodParsing {
    /// Generic-food density knowledge used to ground the model (see FoodDatabase).
    private let database: FoodDatabase

    public init(database: FoodDatabase = .shared) {
        self.database = database
    }

    /// Whether on-device generation is currently usable.
    public static var isAvailable: Bool {
        if case .available = SystemLanguageModel.default.availability { return true }
        return false
    }

    public func parse(text: String, units: UnitSystem) async throws -> ParsedFood {
        guard Self.isAvailable else { throw FoundationModelsError.unavailable }
        // Retrieve generic foods resembling the input and hand the model their real
        // per-100g densities; it still decides the realistic portion and scales.
        let references = database.referenceFoods(text)
        let session = LanguageModelSession(instructions: Prompts.foodInstructions(units: units, references: references))
        let response = try await session.respond(to: text, generating: NutritionInfo.self)
        return response.content.toParsedFood()
    }
}
