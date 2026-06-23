// KeychainStore round-trip + TokenProviding behavior. Each test uses a UUID
// service name and cleans up its namespace so the system Keychain stays tidy and
// tests don't collide. Runs under `swift test` on macOS with the production
// accessibility class (kSecAttrAccessibleWhenUnlockedThisDeviceOnly, no iCloud
// sync) — the same constant the app ships with.

import Testing
import Foundation
import Security
@testable import NutritionAPI

// Wipe all generic-password items for a service (cleanup after each test).
private func cleanup(service: String) {
    let q: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                            kSecAttrService as String: service]
    SecItemDelete(q as CFDictionary)
}

@Suite("KeychainStore — proxy auth token")
struct KeychainStoreTests {

    @Test("save, reload, and delete the auth token")
    func roundTrip() async throws {
        let svc = "com.test.caloriecounter.\(UUID().uuidString)"
        defer { cleanup(service: svc) }
        let store = KeychainStore(service: svc)

        try await store.saveToken("1700000000.deadbeef")
        #expect(await store.authToken() == "1700000000.deadbeef")

        try await store.deleteToken()
        #expect(await store.authToken() == nil)
    }

    @Test("overwriting the token returns the new value (update path)")
    func overwrite() async throws {
        let svc = "com.test.caloriecounter.\(UUID().uuidString)"
        defer { cleanup(service: svc) }
        let store = KeychainStore(service: svc)

        try await store.saveToken("first")
        try await store.saveToken("second")
        #expect(await store.authToken() == "second")
    }

    @Test("tokenRejected() purges the token (called on 401)")
    func tokenRejectedPurges() async throws {
        let svc = "com.test.caloriecounter.\(UUID().uuidString)"
        defer { cleanup(service: svc) }
        let store = KeychainStore(service: svc)

        try await store.saveToken("stale")
        await store.tokenRejected()
        #expect(await store.authToken() == nil)
    }

    @Test("authToken() is nil before anything is stored")
    func emptyByDefault() async throws {
        let svc = "com.test.caloriecounter.\(UUID().uuidString)"
        defer { cleanup(service: svc) }
        #expect(await KeychainStore(service: svc).authToken() == nil)
    }
}
