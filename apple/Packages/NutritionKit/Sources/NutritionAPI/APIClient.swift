// URLSession client for the proxy. An actor so concurrent callers serialize
// safely. Authentication is a short-lived bearer token obtained via Apple App
// Attest (no account, no shipped secret):
//   • requiresAuth requests attach `Authorization: Bearer <jwt>`.
//   • when there's no token, the client acquires one — by refreshing with an
//     assertion if the device is already enrolled, or enrolling first
//     (generateKey → challenge → attest → /register) otherwise.
//   • a 401 purges the token and re-acquires once, transparently.
//   • a 409 ("unknown device") forces re-enrollment.
//
// In development the optional `devBypassSecret` skips attestation (the iOS
// Simulator can't do App Attest); the server honors it only when not in production.

import Foundation
import CryptoKit

public actor APIClient {

    private let environment: APIEnvironment
    private let session: URLSession
    private let tokens: TokenProviding
    private let keyStore: (any AttestKeyStoring)?
    private let attestor: (any AppAttesting)?
    private let devBypassSecret: String?
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    public init(environment: APIEnvironment = .production,
                session: URLSession? = nil,
                tokens: TokenProviding,
                keyStore: (any AttestKeyStoring)? = nil,
                attestor: (any AppAttesting)? = nil,
                devBypassSecret: String? = nil) {
        self.environment = environment
        self.session = session ?? APIClient.makeDefaultSession()
        self.tokens = tokens
        self.keyStore = keyStore
        self.attestor = attestor
        self.devBypassSecret = devBypassSecret
    }

    public static func makeDefaultSession() -> URLSession {
        let config = URLSessionConfiguration.default
        config.httpShouldSetCookies = false
        config.httpCookieAcceptPolicy = .never
        config.httpCookieStorage = nil
        return URLSession(configuration: config)
    }

    // MARK: - Generic send

    public func send<Body: Encodable & Sendable, Response: Decodable & Sendable>(
        _ endpoint: Endpoint, body: Body, as type: Response.Type = Response.self
    ) async throws -> Response {
        let bodyData = try encode(body)
        func attempt() async throws -> Response {
            try decode(try await perform(makeRequest(endpoint, body: bodyData)))
        }
        do {
            return try await attempt()
        } catch APIError.unauthorized {
            // The token was rejected (and already purged by `perform`). Acquire a
            // fresh one via App Attest and retry exactly once.
            try await acquireToken()
            return try await attempt()
        }
    }

    // MARK: - Request building

    private func makeURL(_ endpoint: Endpoint) throws -> URL {
        guard var comps = URLComponents(url: environment.baseURL, resolvingAgainstBaseURL: false) else {
            throw APIError.invalidResponse
        }
        comps.path = endpoint.path
        guard let url = comps.url else { throw APIError.invalidResponse }
        return url
    }

    private func makeRequest(_ endpoint: Endpoint, body: Data?) async throws -> URLRequest {
        var request = URLRequest(url: try makeURL(endpoint))
        request.httpMethod = endpoint.method.rawValue
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if endpoint.requiresAuth {
            let token = try await validBearer()
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        if let body {
            request.httpBody = body
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        return request
    }

    /// The current bearer, acquiring one first if we don't have it yet.
    private func validBearer() async throws -> String {
        if let token = await tokens.authToken() { return token }
        try await acquireToken()
        guard let token = await tokens.authToken() else { throw APIError.unauthorized }
        return token
    }

    // MARK: - Token acquisition (App Attest)

    private func acquireToken() async throws {
        // Dev/Simulator bypass — the server only honors it outside production.
        if let secret = devBypassSecret {
            try await tokens.saveToken(try await requestDevBypassToken(secret: secret))
            return
        }

        guard let attestor, let keyStore, attestor.isSupported else {
            // No attestation available (e.g. Simulator without a bypass configured).
            throw APIError.unauthorized
        }

        if let keyId = await keyStore.attestKeyId() {
            do {
                try await tokens.saveToken(try await refreshToken(keyId: keyId, attestor: attestor))
                return
            } catch APIError.conflict {
                // The server no longer recognizes this key → fall through to re-enroll.
                await keyStore.clearAttestKeyId()
            }
        }
        try await tokens.saveToken(try await enroll(attestor: attestor, keyStore: keyStore))
    }

    /// First-launch enrollment: generate a Secure-Enclave key, attest it over a
    /// fresh challenge, persist the keyId, and return the first bearer token.
    private func enroll(attestor: any AppAttesting, keyStore: any AttestKeyStoring) async throws -> String {
        let keyId = try await attestor.generateKey()
        let challenge = try await fetchChallenge()
        let hash = Self.clientDataHash(challenge.challenge)
        let attestation = try await attestor.attestKey(keyId, clientDataHash: hash)
        let response: TokenResponse = try await postPublic(
            .attestRegister,
            body: AttestRegisterRequest(keyId: keyId,
                                        attestation: attestation.base64EncodedString(),
                                        challengeId: challenge.challengeId)
        )
        try await keyStore.saveAttestKeyId(keyId)
        return response.token
    }

    /// Refresh a token for an already-enrolled device via an assertion. Throws
    /// `APIError.conflict` (409) if the server doesn't recognize the key.
    private func refreshToken(keyId: String, attestor: any AppAttesting) async throws -> String {
        let challenge = try await fetchChallenge()
        let hash = Self.clientDataHash(challenge.challenge)
        let assertion = try await attestor.generateAssertion(keyId, clientDataHash: hash)
        let response: TokenResponse = try await postPublic(
            .attestToken,
            body: AttestAssertRequest(keyId: keyId,
                                      assertion: assertion.base64EncodedString(),
                                      challengeId: challenge.challengeId)
        )
        return response.token
    }

    private func fetchChallenge() async throws -> ChallengeResponse {
        let request = try await makeRequest(.attestChallenge, body: nil)
        return try decode(try await perform(request))
    }

    private func requestDevBypassToken(secret: String) async throws -> String {
        var request = try await makeRequest(.attestToken, body: nil)
        request.setValue(secret, forHTTPHeaderField: "x-attest-dev-bypass")
        let response: TokenResponse = try decode(try await perform(request))
        return response.token
    }

    /// POST to a public endpoint with a JSON body and decode the response.
    private func postPublic<Body: Encodable & Sendable, Response: Decodable & Sendable>(
        _ endpoint: Endpoint, body: Body
    ) async throws -> Response {
        try decode(try await perform(makeRequest(endpoint, body: try encode(body))))
    }

    private static func clientDataHash(_ challenge: String) -> Data {
        Data(SHA256.hash(data: Data(challenge.utf8)))
    }

    // MARK: - Transport

    private func perform(_ request: URLRequest) async throws -> Data {
        let (data, http) = try await performRaw(request)
        if let error = APIError.from(status: http.statusCode, data: data, headers: http.allHeaderFields) {
            if case .unauthorized = error { await tokens.tokenRejected() }
            throw error
        }
        return data
    }

    private func performRaw(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw APIError.transport((error as NSError).localizedDescription)
        }
        guard let http = response as? HTTPURLResponse else { throw APIError.invalidResponse }
        return (data, http)
    }

    // MARK: - Helpers

    private func decode<T: Decodable>(_ data: Data) throws -> T {
        do { return try decoder.decode(T.self, from: data) }
        catch { throw APIError.decoding(String(describing: error)) }
    }

    private func encode<T: Encodable>(_ value: T) throws -> Data {
        do { return try encoder.encode(value) }
        catch { throw APIError.decoding(String(describing: error)) }
    }
}
