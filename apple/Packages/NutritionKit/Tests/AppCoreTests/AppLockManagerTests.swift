// AppLockManager state transitions, driven by a mock biometric gate so no system
// prompt is needed under `swift test`.

import Testing
@testable import AppCore

private struct MockGate: BiometricAuthenticating {
    let available: Bool
    let outcome: BiometricOutcome
    var isAvailable: Bool { get async { available } }
    func authenticate(reason: String) async -> BiometricOutcome { outcome }
}

@MainActor
@Suite("AppLockManager")
struct AppLockManagerTests {

    @Test("starts unlocked by default and lock() engages the lock")
    func lockEngages() {
        let manager = AppLockManager(gate: MockGate(available: true, outcome: .success))
        #expect(manager.isLocked == false)
        manager.lock()
        #expect(manager.isLocked == true)
    }

    @Test("successful biometry unlocks")
    func successUnlocks() async {
        let manager = AppLockManager(gate: MockGate(available: true, outcome: .success), locked: true)
        let unlocked = await manager.authenticate()
        #expect(unlocked == true)
        #expect(manager.isLocked == false)
    }

    @Test("unavailable biometry fails open (unlocks, no lockout)")
    func unavailableFailsOpen() async {
        let manager = AppLockManager(gate: MockGate(available: false, outcome: .unavailable), locked: true)
        #expect(await manager.authenticate() == true)
        #expect(manager.isLocked == false)
    }

    @Test("cancel and failure keep the app locked")
    func cancelAndFailureStayLocked() async {
        let cancelled = AppLockManager(gate: MockGate(available: true, outcome: .userCancel), locked: true)
        #expect(await cancelled.authenticate() == false)
        #expect(cancelled.isLocked == true)

        let failed = AppLockManager(gate: MockGate(available: true, outcome: .failure("too many attempts")), locked: true)
        #expect(await failed.authenticate() == false)
        #expect(failed.isLocked == true)
    }

    @Test("biometryAvailable reflects the gate")
    func availabilityReflectsGate() async {
        #expect(await AppLockManager(gate: MockGate(available: true, outcome: .success)).biometryAvailable() == true)
        #expect(await AppLockManager(gate: MockGate(available: false, outcome: .unavailable)).biometryAvailable() == false)
    }
}
