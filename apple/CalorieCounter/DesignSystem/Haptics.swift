//
//  Haptics.swift
//  A tiny, intentional haptic vocabulary. Each call site says *what happened*
//  (parsed / adjusted / saved / scanSuccess / uncertain), not which generator to
//  use, so the feel stays consistent and tunable in one place. Gated on a settings
//  flag (wired to SettingsStore in Phase 5) and silenced under UI-test / demo runs
//  so deterministic captures never trigger the Taptic Engine.
//

import UIKit
import AppCore

@MainActor
enum Haptics {
    /// Master switch (wired to SettingsStore in Phase 5; default on).
    static var enabled = true

    /// The semantic moments the app expresses through touch.
    enum Event {
        case parsed       // a capture resolved into a meal card — a crisp "got it"
        case adjusted     // a correction chip nudged the numbers — a soft tick
        case saved        // the entry was logged — a confident commit
        case scanSuccess  // a barcode/label locked on — success notification
        case uncertain    // a low-confidence estimate arrived — a gentle, honest tap
    }

    static func fire(_ event: Event) {
        guard enabled, !AppContainer.isUITest, !AppContainer.isDemo else { return }
        switch event {
        case .parsed:
            UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
        case .adjusted:
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        case .saved:
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        case .scanSuccess:
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        case .uncertain:
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }
    }

    // Ergonomic call sites: `Haptics.parsed()` reads at the point of use.
    static func parsed()      { fire(.parsed) }
    static func adjusted()    { fire(.adjusted) }
    static func saved()       { fire(.saved) }
    static func scanSuccess() { fire(.scanSuccess) }
    static func uncertain()   { fire(.uncertain) }
}
