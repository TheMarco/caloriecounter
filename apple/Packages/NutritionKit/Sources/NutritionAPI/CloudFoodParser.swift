// FoodParsing via the `/api/parse-food` OpenAI proxy — the primary text/voice
// parser. The proxy holds the OPENAI_API_KEY; the app only sends the food text.
// Returns the model's nutrition estimate and, for compound dishes, an editable
// ingredient breakdown. Online-only: a network/proxy failure surfaces as an error
// the capture flow shows ("couldn't analyze"), with no on-device fallback.

import Foundation
import NutritionCore

public struct CloudFoodParser: FoodParsing {
    private let client: APIClient

    public init(client: APIClient) { self.client = client }

    public func parse(text: String, units: UnitSystem) async throws -> ParsedFood {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else { throw APIError.badRequest(message: "Type a food to analyze.") }
        let request = ParseFoodRequest(text: trimmed, units: units.rawValue)
        let response: ParseFoodResponse = try await client.send(.parseFood, body: request)
        guard response.success, let data = response.data else {
            throw APIError.badRequest(message: response.error ?? "We couldn’t analyze that. Try rephrasing the food.")
        }
        return data.toDomain()
    }
}
