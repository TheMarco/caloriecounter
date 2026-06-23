// Pure-logic coverage for the error taxonomy (what the UI surfaces to users) and
// the in-memory token store. No network, no stub — safe to run in parallel with
// the stubbed-transport suite.

import Testing
import Foundation
@testable import NutritionAPI

@Suite("APIError status mapping")
struct APIErrorTests {

    private func body(_ json: String) -> Data { Data(json.utf8) }

    @Test("2xx maps to nil (no error)")
    func successIsNil() {
        #expect(APIError.from(status: 200, data: Data(), headers: [:]) == nil)
        #expect(APIError.from(status: 204, data: Data(), headers: [:]) == nil)
    }

    @Test("4xx/5xx statuses map to the right cases, surfacing the body message")
    func statusMapping() {
        #expect(APIError.from(status: 400, data: body(#"{"error":"bad"}"#), headers: [:]) == .badRequest(message: "bad"))
        #expect(APIError.from(status: 401, data: Data(), headers: [:]) == .unauthorized)
        #expect(APIError.from(status: 403, data: body(#"{"error":"nope"}"#), headers: [:]) == .forbidden(message: "nope"))
        #expect(APIError.from(status: 404, data: Data(), headers: [:]) == .notFound)
        #expect(APIError.from(status: 500, data: body(#"{"error":"boom"}"#), headers: [:]) == .server(status: 500, message: "boom"))
        #expect(APIError.from(status: 503, data: Data(), headers: [:]) == .server(status: 503, message: nil))
    }

    @Test("429 reads Retry-After (seconds) then falls back to X-RateLimit-Reset")
    func rateLimitParsing() {
        let retryAfter = APIError.from(status: 429, data: Data(), headers: ["Retry-After": "30"])
        #expect(retryAfter == .rateLimited(retryAfter: 30))

        let reset = APIError.from(status: 429, data: Data(),
                                  headers: ["X-RateLimit-Reset": String(Date().timeIntervalSince1970 + 45)])
        if case let .rateLimited(after) = reset, let after {
            #expect(after > 40 && after <= 45)
        } else {
            Issue.record("expected .rateLimited with a positive interval")
        }

        let none = APIError.from(status: 429, data: Data(), headers: [:])
        #expect(none == .rateLimited(retryAfter: nil))
    }

    @Test("every case has a non-empty user-facing description")
    func descriptions() {
        let cases: [APIError] = [
            .unauthorized, .forbidden(message: nil), .notFound,
            .rateLimited(retryAfter: 12), .rateLimited(retryAfter: nil),
            .badRequest(message: "x"), .server(status: 500, message: nil),
            .transport("offline"), .decoding("bad json"), .invalidResponse,
        ]
        for error in cases {
            #expect(!(error.errorDescription ?? "").isEmpty)
        }
    }
}

@Suite("InMemoryTokenStore")
struct InMemoryTokenStoreTests {

    @Test("save → read → reject round-trip")
    func roundTrip() async throws {
        let store = InMemoryTokenStore()
        #expect(await store.authToken() == nil)

        try await store.saveToken("abc.def")
        #expect(await store.authToken() == "abc.def")

        await store.tokenRejected()
        #expect(await store.authToken() == nil)
    }

    @Test("seeded token is readable immediately")
    func seeded() async {
        #expect(await InMemoryTokenStore(token: "seed").authToken() == "seed")
    }
}
