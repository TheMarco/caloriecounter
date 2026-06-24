// Whether on-device Apple Intelligence (Foundation Models) is usable, and WHY not
// when it isn't — so the app can nudge only the users a nudge can actually help.
//
// Pure Core (no FoundationModels import); NutritionAI maps the framework's
// availability onto this, and AppCore decides whether to surface the hint.

import Foundation

public enum AIAvailability: Sendable, Equatable {
    /// The model is ready to use.
    case available
    /// Capable device, but Apple Intelligence is switched off in Settings — the only
    /// case worth prompting the user about.
    case notEnabled
    /// The hardware can't run Apple Intelligence — never prompt (nothing to enable).
    case deviceNotEligible
    /// Capable + enabled, but the model is still downloading / preparing.
    case modelNotReady
    /// Any other / unknown reason.
    case unavailable

    /// True only when prompting the user to turn Apple Intelligence on would help:
    /// the device is capable but it's off. Not for ineligible hardware or mid-download.
    public var suggestsEnabling: Bool { self == .notEnabled }
}
