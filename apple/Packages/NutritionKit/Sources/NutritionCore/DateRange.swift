// History-view range presets. Ported from the web `DateRange` union
// ('7d' | '30d' | '90d') and the `DATE_RANGES` table in `src/lib/constants.ts`.
// Raw values match the web keys so persisted/UI selections line up.

import Foundation

public enum DateRange: String, Codable, Sendable, CaseIterable {
    case week = "7d"
    case month = "30d"
    case quarter = "90d"

    /// Number of days the range spans (web `DATE_RANGES[*].days`).
    public var days: Int {
        switch self {
        case .week: return 7
        case .month: return 30
        case .quarter: return 90
        }
    }

    /// Picker label (web `DATE_RANGES[*].label`).
    public var label: String {
        switch self {
        case .week: return "7 Days"
        case .month: return "30 Days"
        case .quarter: return "90 Days"
        }
    }
}
