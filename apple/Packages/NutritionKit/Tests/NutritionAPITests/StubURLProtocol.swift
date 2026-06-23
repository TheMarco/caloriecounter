// In-process URLProtocol stub so the API layer is testable with no network under
// `swift test` on macOS (DoD: no live network in tests). Captures the outgoing
// request and returns a canned response set per test. Adapted from the
// MyAIJournal pattern.

import Foundation
@testable import NutritionAPI

struct StubResponse: Sendable {
    var status: Int
    var headers: [String: String]
    var body: Data

    init(status: Int = 200, headers: [String: String] = [:], body: Data = Data()) {
        self.status = status; self.headers = headers; self.body = body
    }
    static func json(_ status: Int = 200, headers: [String: String] = [:], _ json: String) -> StubResponse {
        StubResponse(status: status, headers: headers, body: Data(json.utf8))
    }
}

struct CapturedRequest: Sendable {
    var url: URL?
    var method: String?
    var headers: [String: String]
    var body: Data?

    /// Case-insensitive header lookup (URLSession may re-case header names).
    func header(_ name: String) -> String? {
        for (k, v) in headers where k.caseInsensitiveCompare(name) == .orderedSame { return v }
        return nil
    }
    var bodyJSON: [String: Any]? {
        guard let body, let obj = try? JSONSerialization.jsonObject(with: body) else { return nil }
        return obj as? [String: Any]
    }
}

final class StubURLProtocol: URLProtocol, @unchecked Sendable {
    private static let lock = NSLock()
    nonisolated(unsafe) private static var _handler: (@Sendable (URLRequest) -> StubResponse)?
    nonisolated(unsafe) private static var _captured: CapturedRequest?

    static func stub(_ handler: @escaping @Sendable (URLRequest) -> StubResponse) {
        lock.lock(); defer { lock.unlock() }
        _handler = handler; _captured = nil
    }
    static func reset() {
        lock.lock(); defer { lock.unlock() }
        _handler = nil; _captured = nil
    }
    static func captured() -> CapturedRequest? {
        lock.lock(); defer { lock.unlock() }
        return _captured
    }

    /// A URLSession wired to this stub. Cookie handling is disabled so the
    /// client's manually-set `Cookie` header passes through verbatim (matching
    /// the production session config).
    static func makeSession() -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StubURLProtocol.self]
        config.httpShouldSetCookies = false
        config.httpCookieAcceptPolicy = .never
        config.httpCookieStorage = nil
        return URLSession(configuration: config)
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let captured = CapturedRequest(
            url: request.url,
            method: request.httpMethod,
            headers: request.allHTTPHeaderFields ?? [:],
            body: Self.readBody(request)
        )
        let handler: (@Sendable (URLRequest) -> StubResponse)?
        Self.lock.lock()
        Self._captured = captured
        handler = Self._handler
        Self.lock.unlock()

        guard let handler, let url = request.url else {
            client?.urlProtocol(self, didFailWithError: URLError(.unsupportedURL))
            return
        }
        let stub = handler(request)
        let response = HTTPURLResponse(url: url, statusCode: stub.status, httpVersion: "HTTP/1.1", headerFields: stub.headers)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: stub.body)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}

    /// URLSession moves httpBody into httpBodyStream; read it back for assertions.
    private static func readBody(_ request: URLRequest) -> Data? {
        if let body = request.httpBody { return body }
        guard let stream = request.httpBodyStream else { return nil }
        stream.open(); defer { stream.close() }
        var data = Data()
        let size = 4096
        var buffer = [UInt8](repeating: 0, count: size)
        while stream.hasBytesAvailable {
            let read = stream.read(&buffer, maxLength: size)
            if read <= 0 { break }
            data.append(buffer, count: read)
        }
        return data
    }
}

/// Records token saves / 401 rejections so tests can assert client behavior
/// without touching the Keychain.
actor RecordingTokenStore: TokenProviding {
    private(set) var token: String?
    private(set) var rejections = 0
    private(set) var saves = 0
    init(_ token: String? = nil) { self.token = token }
    func authToken() async -> String? { token }
    func saveToken(_ token: String) async throws { self.token = token; saves += 1 }
    func tokenRejected() async { token = nil; rejections += 1 }
}
