// Typed endpoint catalog for the proxy. The two AI endpoints are bearer-token
// authenticated — `requiresAuth` endpoints get an `Authorization: Bearer <jwt>`
// header from APIClient. The `/api/attest/*` endpoints are public (they're how a
// token is obtained via App Attest), so `requiresAuth: false`.

import Foundation

public enum HTTPMethod: String, Sendable {
    case get = "GET", post = "POST"
}

public struct Endpoint: Sendable {
    public let method: HTTPMethod
    public let path: String
    public let requiresAuth: Bool

    public init(_ method: HTTPMethod, _ path: String, requiresAuth: Bool = true) {
        self.method = method
        self.path = path
        self.requiresAuth = requiresAuth
    }

    /// Plate-photo analysis. Bearer-authenticated.
    public static let parsePhoto = Endpoint(.post, "/api/parse-photo")
    /// Text/voice food description → OpenAI nutrition + breakdown. Bearer-authenticated.
    public static let parseFood = Endpoint(.post, "/api/parse-food")

    // App Attest token acquisition (all public).
    /// Request a one-time challenge to sign.
    public static let attestChallenge = Endpoint(.post, "/api/attest/challenge", requiresAuth: false)
    /// First-launch enrollment: send the attestation, get the first token.
    public static let attestRegister = Endpoint(.post, "/api/attest/register", requiresAuth: false)
    /// Token refresh via an assertion (also the dev-bypass path).
    public static let attestToken = Endpoint(.post, "/api/attest/token", requiresAuth: false)
}
