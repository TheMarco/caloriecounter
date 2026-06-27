// Base URL config for the Next.js proxy. Production is the deployed web app's
// domain (which hosts /api/auth + /api/parse-photo); `.development` points at a
// local `next dev` proxy for on-device/simulator testing.

import Foundation

public struct APIEnvironment: Sendable {
    public var baseURL: URL

    public init(baseURL: URL) { self.baseURL = baseURL }

    public static let production = APIEnvironment(baseURL: URL(string: "https://calorietracker.ai-created.com")!)
    public static let development = APIEnvironment(baseURL: URL(string: "http://localhost:3000")!)
}
