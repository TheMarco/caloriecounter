// CaptureErrorInfo: the pure copy + recovery mapping for capture failures, so each
// input shows a specific, actionable state (not a generic "OK" alert).

import Testing
@testable import AppCore

@Suite("CaptureErrorInfo")
struct CaptureErrorInfoTests {

    @Test("every kind has non-empty title, message, and symbol")
    func populated() {
        for kind in CaptureErrorInfo.Kind.allCases {
            let info = CaptureErrorInfo.from(kind)
            #expect(!info.title.isEmpty)
            #expect(!info.message.isEmpty)
            #expect(!info.symbol.isEmpty)
            #expect(!info.primaryLabel.isEmpty)
        }
    }

    @Test("permission failures recover by opening Settings")
    func permissionsOpenSettings() {
        for kind in [CaptureErrorInfo.Kind.cameraPermission, .microphonePermission] {
            let info = CaptureErrorInfo.from(kind)
            #expect(info.primary == .openSettings)
            #expect(info.primaryLabel == "Open Settings")
        }
    }

    @Test("transient failures recover by retrying")
    func transientRetry() {
        for kind in [CaptureErrorInfo.Kind.network, .unreadable, .barcodeNotFound, .photoUnusable] {
            #expect(CaptureErrorInfo.from(kind).primary == .retry)
        }
    }

    @Test("the network state names the estimator, not a generic failure")
    func networkCopy() {
        #expect(CaptureErrorInfo.from(.network).message.lowercased().contains("connect"))
        #expect(CaptureErrorInfo.from(.network).title.lowercased().contains("estimator"))
    }

    @Test("the copy stays kind — no blame language")
    func noBlame() {
        let banned = ["bad", "wrong", "stupid", "failed you", "your fault"]
        for kind in CaptureErrorInfo.Kind.allCases {
            let text = (CaptureErrorInfo.from(kind).title + " " + CaptureErrorInfo.from(kind).message).lowercased()
            for word in banned { #expect(!text.contains(word)) }
        }
    }
}
