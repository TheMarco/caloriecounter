// Measurement system preference. Drives the units the AI parsers are asked to
// produce (grams/ml vs oz/lb/cups) — see the metric/imperial branch in
// `src/app/api/parse-food/route.ts` and `parse-photo/route.ts`. The web app
// keys this off `AppSettings.units`.

import Foundation

public enum UnitSystem: String, Codable, Sendable, CaseIterable {
    case metric
    case imperial

    /// Human-readable picker label.
    public var label: String {
        switch self {
        case .metric: return "Metric"
        case .imperial: return "Imperial"
        }
    }
}
