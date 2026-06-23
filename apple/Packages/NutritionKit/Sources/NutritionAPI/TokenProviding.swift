// The auth-token seam between APIClient and its credential store. The token is
// the web app's signed `calorie-auth` value (`timestamp.signature`); APIClient
// neither knows nor cares that it lives in the Keychain.

import Foundation

public protocol TokenProviding: Sendable {
    /// The current proxy auth token, or nil if not logged in.
    func authToken() async -> String?
    /// Persist a freshly issued token (after a successful login).
    func saveToken(_ token: String) async throws
    /// Called by APIClient on a 401 — purge the token so the app routes to re-login.
    func tokenRejected() async
}

/// Non-persistent token store for previews/tests. The shipping app uses
/// `KeychainStore`.
public actor InMemoryTokenStore: TokenProviding {
    private var token: String?
    public init(token: String? = nil) { self.token = token }
    public func authToken() async -> String? { token }
    public func saveToken(_ token: String) async throws { self.token = token }
    public func tokenRejected() async { token = nil }
}
