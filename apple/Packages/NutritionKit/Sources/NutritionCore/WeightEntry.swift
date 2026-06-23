// A body-weight measurement. Logged whenever the user likes (not necessarily
// daily), so it's a sparse time series keyed by local day — at most one per day
// (re-logging a day updates it). Weight is stored canonically in kilograms; the
// UI converts to the user's unit system for display/entry.

import Foundation

public struct WeightEntry: Identifiable, Codable, Sendable, Equatable {
    /// Stable identity. One measurement per local day → `weight-<YYYY-MM-DD>`.
    public let id: String
    /// Local calendar day, `YYYY-MM-DD` (see `LocalDate`).
    public var date: String
    /// Instant the measurement was logged (ordering / "latest").
    public var timestamp: Date
    /// Body weight in kilograms (canonical; convert for display).
    public var weightKg: Double

    public init(id: String, date: String, timestamp: Date, weightKg: Double) {
        self.id = id
        self.date = date
        self.timestamp = timestamp
        self.weightKg = weightKg
    }

    /// The conventional id for a given day (one measurement per day).
    public static func id(for date: String) -> String { "weight-\(date)" }
}
