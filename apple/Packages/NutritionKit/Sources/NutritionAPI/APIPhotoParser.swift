// PhotoParsing via the `/api/parse-photo` proxy — the ONLY cloud AI call in the
// app. The image is sent as a base64 data URL (the route validates a
// `data:image/…` prefix); the on-device OPENAI_API_KEY is never involved.

import Foundation
import NutritionCore

public struct APIPhotoParser: PhotoParsing {
    private let client: APIClient

    public init(client: APIClient) { self.client = client }

    public func parse(imageData: Data, units: UnitSystem, details: PhotoDetails) async throws -> ParsedFood {
        let dataURL = "data:image/jpeg;base64,\(imageData.base64EncodedString())"
        let request = ParsePhotoRequest(imageData: dataURL, units: units.rawValue, details: details)
        let response: ParsePhotoResponse = try await client.send(.parsePhoto, body: request)
        guard response.success, let data = response.data else {
            throw APIError.badRequest(message: response.error ?? "Photo analysis failed.")
        }
        return data.toDomain()
    }
}
