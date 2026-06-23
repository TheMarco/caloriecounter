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

public actor KeychainStore: TokenProviding {

    public let service: String
    private let account = "calorie-auth-token"

    public init(service: String = "com.aidashcreated.caloriecounter") {
        self.service = service
    }

    // MARK: - TokenProviding

    public func authToken() async -> String? {
        loadItem().flatMap { String(data: $0, encoding: .utf8) }
    }

    public func saveToken(_ token: String) throws {
        try saveItem(Data(token.utf8))
    }

    public func tokenRejected() async {
        try? deleteItem()
    }

    public func deleteToken() throws {
        try deleteItem()
    }

    // MARK: - SecItem primitives (update-first / add-on-not-found)

    private func saveItem(_ data: Data) throws {
        let accessible = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        let status: OSStatus
        if loadItem() != nil {
            let attrs: [String: Any] = [kSecValueData as String: data,
                                        kSecAttrAccessible as String: accessible]
            status = SecItemUpdate(baseQuery() as CFDictionary, attrs as CFDictionary)
        } else {
            var q = baseQuery()
            q[kSecValueData as String] = data
            q[kSecAttrAccessible as String] = accessible
            status = SecItemAdd(q as CFDictionary, nil)
        }
        guard status == errSecSuccess else { throw KeychainError.saveFailed(status) }
    }

    private func loadItem() -> Data? {
        var q = baseQuery()
        q[kSecReturnData as String] = true
        q[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: AnyObject?
        guard SecItemCopyMatching(q as CFDictionary, &result) == errSecSuccess else { return nil }
        return result as? Data
    }

    private func deleteItem() throws {
        let status = SecItemDelete(baseQuery() as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.deleteFailed(status)
        }
    }

    private func baseQuery() -> [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: service,
         kSecAttrAccount as String: account]
    }
}

public enum KeychainError: Error, Equatable, Sendable {
    case saveFailed(OSStatus)
    case deleteFailed(OSStatus)
}
