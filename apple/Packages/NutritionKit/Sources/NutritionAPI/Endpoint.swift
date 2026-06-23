// Typed endpoint catalog for the proxy. Only two endpoints are needed: the
// plate-photo parser (the single cloud AI call) and the password login. Auth is
// the web app's signed `calorie-auth` cookie — `requiresAuth` endpoints get it
// attached as a Cookie header by APIClient.

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

    /// Plate-photo analysis (the only cloud AI call). Cookie-authenticated.
    public static let parsePhoto = Endpoint(.post, "/api/parse-photo")
    /// Exchange the shared password for the `calorie-auth` cookie token. Public.
    public static let authLogin = Endpoint(.post, "/api/auth", requiresAuth: false)
}
