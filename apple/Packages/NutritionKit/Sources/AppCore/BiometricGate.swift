// Face ID / Touch ID prompt. The actor serializes concurrent auth requests; the
// LAContext is created fresh per call so there's no shared mutable state. A
// `BiometricAuthenticating` protocol lets AppLockManager be unit-tested with a
// mock (the real gate can't prompt under `swift test`).
//
// @preconcurrency import suppresses Sendable checks for LAContext (a pre-Swift-6
// ObjC class) — Apple's recommended migration path.

@preconcurrency import LocalAuthentication
import Foundation

public enum BiometricOutcome: Sendable, Equatable {
    case success
    case userCancel
    case unavailable          // not enrolled, or hardware absent (simulator/Mac)
    case failure(String)
}

public protocol BiometricAuthenticating: Sendable {
    /// Whether biometry is enrolled and available right now.
    var isAvailable: Bool { get async }
    /// Present the system biometry prompt.
    func authenticate(reason: String) async -> BiometricOutcome
}

public actor BiometricGate: BiometricAuthenticating {
    public init() {}

    public var isAvailable: Bool {
        LAContext().canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
    }

    public func authenticate(reason: String) async -> BiometricOutcome {
        let ctx = LAContext()
        var error: NSError?
        guard ctx.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            return .unavailable
        }
        return await withCheckedContinuation { continuation in
            ctx.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason) { success, err in
                let outcome: BiometricOutcome
                if success {
                    outcome = .success
                } else if let e = err as? LAError {
                    switch e.code {
                    case .userCancel, .appCancel, .systemCancel: outcome = .userCancel
                    default: outcome = .failure(e.localizedDescription)
                    }
                } else {
                    outcome = .unavailable
                }
                continuation.resume(returning: outcome)
            }
        }
    }
}
