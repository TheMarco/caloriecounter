// CaptureErrorInfo — turns a capture failure into a specific, kind, recoverable
// message. Each input (camera permission, mic, barcode miss, network) gets its own
// honest copy and a clear next step, instead of a generic "OK" alert. Pure +
// unit-tested; the view renders it and wires the recovery action.

import Foundation

public struct CaptureErrorInfo: Sendable, Equatable {

    public enum Kind: Sendable, Equatable, CaseIterable {
        case cameraPermission       // camera access denied (photo / barcode)
        case microphonePermission   // mic / speech access denied (voice)
        case speechUnavailable      // speech recognition not available right now
        case barcodeNotFound        // no nutrition for that barcode
        case network                // couldn't reach the cloud estimator
        case unreadable             // couldn't make out the food/amount
        case photoUnusable          // the captured image didn't work
    }

    /// How the user can move forward.
    public enum Recovery: Sendable, Equatable {
        case openSettings   // jump to the app's Settings page
        case retry          // try the capture/parse again
        case dismiss        // just close
    }

    public let kind: Kind
    public var title: String
    public var message: String
    public var symbol: String
    public var primary: Recovery
    public var primaryLabel: String

    public static func from(_ kind: Kind) -> CaptureErrorInfo {
        switch kind {
        case .cameraPermission:
            return .init(kind: kind,
                         title: "Camera access is off",
                         message: "Turn on camera access in Settings to scan or snap your food.",
                         symbol: "camera.fill",
                         primary: .openSettings, primaryLabel: "Open Settings")
        case .microphonePermission:
            return .init(kind: kind,
                         title: "Microphone access is off",
                         message: "Turn on Microphone and Speech Recognition in Settings to speak your food.",
                         symbol: "mic.slash.fill",
                         primary: .openSettings, primaryLabel: "Open Settings")
        case .speechUnavailable:
            return .init(kind: kind,
                         title: "Voice isn't available",
                         message: "Speech recognition isn't available right now. You can type your food instead.",
                         symbol: "waveform.slash",
                         primary: .dismiss, primaryLabel: "OK")
        case .barcodeNotFound:
            return .init(kind: kind,
                         title: "No match for that barcode",
                         message: "We couldn't find nutrition for it. Try a photo of the label, or type it instead.",
                         symbol: "barcode.viewfinder",
                         primary: .retry, primaryLabel: "Scan Again")
        case .network:
            return .init(kind: kind,
                         title: "Couldn't reach the estimator",
                         message: "We couldn't connect to estimate this food. Check your connection, then try again.",
                         symbol: "wifi.slash",
                         primary: .retry, primaryLabel: "Try Again")
        case .unreadable:
            return .init(kind: kind,
                         title: "Didn't catch that",
                         message: "We couldn't make out the food and amount. Try rephrasing it.",
                         symbol: "questionmark.circle",
                         primary: .retry, primaryLabel: "Try Again")
        case .photoUnusable:
            return .init(kind: kind,
                         title: "Couldn't use that photo",
                         message: "That image didn't work. Retake it, or type the food instead.",
                         symbol: "photo.badge.exclamationmark",
                         primary: .retry, primaryLabel: "Retake")
        }
    }
}
