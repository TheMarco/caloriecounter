// URLSession client for the proxy. An actor so concurrent callers serialize
// safely. The web app authenticates with a signed `calorie-auth` cookie, so this
// client:
//   • login(password:) POSTs the password, reads the `calorie-auth` token from
//     the Set-Cookie response header, and hands it to the token store (Keychain).
//   • attaches `Cookie: calorie-auth=<token>` to every `requiresAuth` request.
//   • on 401, purges the token via the store so the app routes to re-login.
//
// Cookie handling is disabled on the default session so the manually-managed
// Cookie header is authoritative (no stale/auto cookies).

import Foundation

public actor APIClient {
    public static let cookieName = "calorie-auth"

    private let environment: APIEnvironment
    private let session: URLSession
    private let tokens: TokenProviding
    /// When set, a request that comes back unauthorized (no token yet, or the 24h
    /// token expired) transparently logs in with this shared password and retries
    /// once — so there's no login screen to present or babysit.
    private let autoLoginPassword: String?
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    public init(environment: APIEnvironment = .production, session: URLSession? = nil,
                tokens: TokenProviding, autoLoginPassword: String? = nil) {
        self.environment = environment
        self.session = session ?? APIClient.makeDefaultSession()
        self.tokens = tokens
        self.autoLoginPassword = autoLoginPassword
    }

    /// Production session with cookie auto-handling OFF (we set the Cookie header
    /// ourselves from the Keychain-backed token).
    public static func makeDefaultSession() -> URLSession {
        let config = URLSessionConfiguration.default
        config.httpShouldSetCookies = false
        config.httpCookieAcceptPolicy = .never
        config.httpCookieStorage = nil
        return URLSession(configuration: config)
    }

    // MARK: - Login (password → cookie token)

    /// Exchange the shared password for the `calorie-auth` token and store it.
    public func login(password: String) async throws {
        let request = try await makeRequest(.authLogin, body: try encode(AuthRequest(password: password)))
        let (data, http) = try await performRaw(request)
        if let error = APIError.from(status: http.statusCode, data: data, headers: http.allHeaderFields) {
            throw error
        }
        guard let url = http.url, let token = Self.extractToken(from: http, url: url) else {
            throw APIError.invalidResponse
        }
        try await tokens.saveToken(token)
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
            // Missing or expired token → log in with the shared password and retry once.
            guard let password = autoLoginPassword else { throw APIError.unauthorized }
            try await login(password: password)
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
            guard let token = await tokens.authToken() else { throw APIError.unauthorized }
            request.setValue("\(Self.cookieName)=\(token)", forHTTPHeaderField: "Cookie")
        }
        if let body {
            request.httpBody = body
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        return request
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

    /// Pull the `calorie-auth` value out of the response's Set-Cookie header.
    /// HTTP/2 (Vercel) lowercases header names, so find Set-Cookie
    /// case-insensitively and hand it to the cookie parser under the canonical key.
    private static func extractToken(from http: HTTPURLResponse, url: URL) -> String? {
        var setCookie: String?
        for (key, value) in http.allHeaderFields {
            if (key as? String)?.caseInsensitiveCompare("Set-Cookie") == .orderedSame {
                setCookie = value as? String
                break
            }
        }
        guard let setCookie else { return nil }
        let cookies = HTTPCookie.cookies(withResponseHeaderFields: ["Set-Cookie": setCookie], for: url)
        return cookies.first(where: { $0.name == cookieName })?.value
    }

    private func decode<T: Decodable>(_ data: Data) throws -> T {
        do { return try decoder.decode(T.self, from: data) }
        catch { throw APIError.decoding(String(describing: error)) }
    }

    private func encode<T: Encodable>(_ value: T) throws -> Data {
        do { return try encoder.encode(value) }
        catch { throw APIError.decoding(String(describing: error)) }
    }
}
