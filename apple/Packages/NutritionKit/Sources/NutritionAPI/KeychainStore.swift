// Keychain-backed store for the proxy auth token (the only secret the app holds).
// Implements TokenProviding so APIClient can use it without knowing about the
// Keychain.
//
// Security (per plan): kSecAttrAccessibleWhenUnlockedThisDeviceOnly — the token
// is readable only while the device is unlocked and NEVER syncs to iCloud
// (ThisDeviceOnly). No master key / crypto here; SwiftData data-at-rest relies on
// OS Data Protection. The OpenAI key is never stored — it stays server-side.

import Foundation
import Security

public actor KeychainStore: TokenProviding, AttestKeyStoring {

    public let service: String
    private let account = "calorie-auth-token"
    /// The App Attest enrollment keyId. Persisted (ThisDeviceOnly, no iCloud) so
    /// the device enrolls once; the bearer token is re-derived from it on demand.
    private let keyIdAccount = "appattest-key-id"

    public init(service: String = "com.aidashcreated.caloriecounter") {
        self.service = service
    }

    // MARK: - TokenProviding (the short-lived bearer token)

    public func authToken() async -> String? {
        loadItem(account).flatMap { String(data: $0, encoding: .utf8) }
    }

    public func saveToken(_ token: String) throws {
        try saveItem(Data(token.utf8), account: account)
    }

    public func tokenRejected() async {
        try? deleteItem(account)
    }

    public func deleteToken() throws {
        try deleteItem(account)
    }

    // MARK: - AttestKeyStoring (the durable enrollment keyId)

    public func attestKeyId() async -> String? {
        loadItem(keyIdAccount).flatMap { String(data: $0, encoding: .utf8) }
    }

    public func saveAttestKeyId(_ keyId: String) throws {
        try saveItem(Data(keyId.utf8), account: keyIdAccount)
    }

    public func clearAttestKeyId() async {
        try? deleteItem(keyIdAccount)
    }

    // MARK: - SecItem primitives (update-first / add-on-not-found)

    private func saveItem(_ data: Data, account: String) throws {
        let accessible = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        let status: OSStatus
        if loadItem(account) != nil {
            let attrs: [String: Any] = [kSecValueData as String: data,
                                        kSecAttrAccessible as String: accessible]
            status = SecItemUpdate(baseQuery(account) as CFDictionary, attrs as CFDictionary)
        } else {
            var q = baseQuery(account)
            q[kSecValueData as String] = data
            q[kSecAttrAccessible as String] = accessible
            status = SecItemAdd(q as CFDictionary, nil)
        }
        guard status == errSecSuccess else { throw KeychainError.saveFailed(status) }
    }

    private func loadItem(_ account: String) -> Data? {
        var q = baseQuery(account)
        q[kSecReturnData as String] = true
        q[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: AnyObject?
        guard SecItemCopyMatching(q as CFDictionary, &result) == errSecSuccess else { return nil }
        return result as? Data
    }

    private func deleteItem(_ account: String) throws {
        let status = SecItemDelete(baseQuery(account) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.deleteFailed(status)
        }
    }

    private func baseQuery(_ account: String) -> [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: service,
         kSecAttrAccount as String: account]
    }
}

public enum KeychainError: Error, Equatable, Sendable {
    case saveFailed(OSStatus)
    case deleteFailed(OSStatus)
}
