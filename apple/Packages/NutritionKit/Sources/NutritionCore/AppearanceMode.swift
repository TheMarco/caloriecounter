// User's color-scheme preference. Pure (no SwiftUI) so it lives in Core and is
// persisted by SettingsStore; the app layer maps it to a SwiftUI `ColorScheme?`.

import Foundation

public enum AppearanceMode: String, Codable, Sendable, CaseIterable {
    case system
    case light
    case dark

    /// Segmented-picker label.
    public var label: String {
        switch self {
        case .system: return "Auto"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }
}
