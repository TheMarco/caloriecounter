// Drives the optional Face ID app lock. `@Observable` so the root view re-renders
// when `isLocked` flips. The biometric prompt is delegated to a
// `BiometricAuthenticating` (the real `BiometricGate`, or a mock in tests).
//
// Fail-open policy: if biometry is unavailable on the device (no enrollment,
// simulator), authentication unlocks rather than permanently locking the user
// out of their own local data.

import Foundation
import Observation

@Observable
@MainActor
public final class AppLockManager {
    public private(set) var isLocked: Bool

    @ObservationIgnored private let gate: any BiometricAuthenticating

    public init(gate: any BiometricAuthenticating = BiometricGate(), locked: Bool = false) {
        self.gate = gate
        self.isLocked = locked
    }

    /// Re-engage the lock (call when enabling the setting or on background).
    public func lock() { isLocked = true }

    /// Present biometry and unlock on success (or when biometry is unavailable).
    /// Returns whether the app is now unlocked.
    @discardableResult
    public func authenticate(reason: String = "Unlock CalorieCounter") async -> Bool {
        switch await gate.authenticate(reason: reason) {
        case .success, .unavailable:
            isLocked = false
            return true
        case .userCancel, .failure:
            return false
        }
    }

    public func biometryAvailable() async -> Bool {
        await gate.isAvailable
    }
}
