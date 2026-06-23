// User preferences — the Swift port of the web `AppSettings`
// (`calorie-counter-settings` in localStorage): daily macro targets plus the
// metric/imperial unit preference. The Face-ID app-lock toggle is a separate
// device-only concern handled by `SettingsStore` in AppCore (Phase 5).

import Foundation

public struct AppSettings: Codable, Sendable, Equatable {
    public var targets: MacroTargets
    public var units: UnitSystem

    public init(targets: MacroTargets = .default, units: UnitSystem = .metric) {
        self.targets = targets
        self.units = units
    }

    /// Web defaults: default targets, metric units.
    public static let `default` = AppSettings()
}
