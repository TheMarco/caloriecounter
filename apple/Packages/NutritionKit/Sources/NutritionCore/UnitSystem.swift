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

    /// Sensible default for a fresh install, inferred from the device locale:
    /// US region → imperial (lb / ft·in), everywhere else → metric.
    public static var deviceDefault: UnitSystem {
        Locale.current.measurementSystem == .us ? .imperial : .metric
    }

    // MARK: - Body-weight conversion (canonical storage is kilograms)

    public static let poundsPerKilogram = 2.2046226

    /// Short label for body weight in this system.
    public var weightUnit: String { self == .metric ? "kg" : "lb" }

    /// Convert canonical kilograms into this system's display value.
    public func weightForDisplay(kg: Double) -> Double {
        self == .metric ? kg : kg * Self.poundsPerKilogram
    }

    /// Convert a display value in this system back into canonical kilograms.
    public func kilograms(fromDisplay value: Double) -> Double {
        self == .metric ? value : value / Self.poundsPerKilogram
    }
}
