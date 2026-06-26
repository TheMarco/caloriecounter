// The App Attest seam. `APIClient` proves the app is a genuine, unmodified build
// on a real Apple device by signing server challenges with a Secure-Enclave key,
// instead of shipping a static password. The capability is abstracted so tests
// (and the macOS test host, where App Attest doesn't exist) inject a mock.
//
//   • `AppAttesting`     — generate a key, attest it (enrollment), sign assertions.
//   • `AttestKeyStoring` — persist the enrolled keyId (the bearer token itself is
//     short-lived and re-derived on demand, so only the keyId needs to survive).
//
// The real implementation, `DeviceCheckAttestor`, wraps `DCAppAttestService` and
// is compiled only for iOS (device + simulator). On the simulator `isSupported`
// is false, so the app falls back to the dev bypass.

import Foundation

public protocol AppAttesting: Sendable {
    /// False on the Simulator and unsupported devices — callers must fall back.
    var isSupported: Bool { get }
    /// Create a new Secure-Enclave key, returning its base64 keyId.
    func generateKey() async throws -> String
    /// Attest `keyId` over `clientDataHash` (SHA256 of the server challenge) →
    /// the CBOR attestation object to send to `/api/attest/register`.
    func attestKey(_ keyId: String, clientDataHash: Data) async throws -> Data
    /// Sign `clientDataHash` with `keyId` → the CBOR assertion for `/api/attest/token`.
    func generateAssertion(_ keyId: String, clientDataHash: Data) async throws -> Data
}

public protocol AttestKeyStoring: Sendable {
    func attestKeyId() async -> String?
    func saveAttestKeyId(_ keyId: String) async throws
    func clearAttestKeyId() async
}

/// Non-persistent keyId store for previews/tests.
public actor InMemoryAttestKeyStore: AttestKeyStoring {
    private var keyId: String?
    public init(keyId: String? = nil) { self.keyId = keyId }
    public func attestKeyId() async -> String? { keyId }
    public func saveAttestKeyId(_ keyId: String) async throws { self.keyId = keyId }
    public func clearAttestKeyId() async { keyId = nil }
}

#if os(iOS)
import DeviceCheck

/// Real App Attest backed by `DCAppAttestService`. iOS-only — the macOS test
/// host compiles this file to nothing.
public struct DeviceCheckAttestor: AppAttesting {
    public init() {}

    public var isSupported: Bool { DCAppAttestService.shared.isSupported }

    public func generateKey() async throws -> String {
        try await DCAppAttestService.shared.generateKey()
    }

    public func attestKey(_ keyId: String, clientDataHash: Data) async throws -> Data {
        try await DCAppAttestService.shared.attestKey(keyId, clientDataHash: clientDataHash)
    }

    public func generateAssertion(_ keyId: String, clientDataHash: Data) async throws -> Data {
        try await DCAppAttestService.shared.generateAssertion(keyId, clientDataHash: clientDataHash)
    }
}
#endif
