// Import of the app's own daily-totals CSV (the inverse of CSVExporter). Each row
// is one day, so import restores a day's macros as a single "Imported daily total"
// entry plus its exercise offset — a round-trip of the export, used for backup or
// moving between devices. Pure parsing + a store-apply, both unit-tested.

import Foundation
import NutritionCore

public struct ImportedDay: Sendable, Equatable {
    public let date: String
    public let calories: Double
    public let carbs: Double
    public let fat: Double
    public let protein: Double
    public let offset: Double
}

public enum CSVImporter {
    public enum ImportError: Error, Equatable {
        case missingHeader   // not a CalorieCounter export
        case noRows          // header ok but no usable data
    }

    /// Parse the export CSV into per-day rows (ignores the derived net column).
    public static func parse(_ csv: String) throws -> [ImportedDay] {
        let lines = csv.split(whereSeparator: \.isNewline).map(String.init)
        guard let header = lines.first,
              header.replacingOccurrences(of: " ", with: "").lowercased()
                .hasPrefix("date,calories_consumed,calories_burned,net_calories,carbs,fat,protein")
        else { throw ImportError.missingHeader }

        var days: [ImportedDay] = []
        for line in lines.dropFirst() {
            let f = line.split(separator: ",", omittingEmptySubsequences: false)
                .map { $0.trimmingCharacters(in: .whitespaces) }
            guard f.count >= 7, isValidDateKey(f[0]) else { continue }
            days.append(ImportedDay(
                date: f[0],
                calories: Double(f[1]) ?? 0,
                carbs: Double(f[4]) ?? 0,
                fat: Double(f[5]) ?? 0,
                protein: Double(f[6]) ?? 0,
                offset: Double(f[2]) ?? 0
            ))
        }
        guard !days.isEmpty else { throw ImportError.noRows }
        return days
    }

    /// Persist parsed days: one synthetic "Imported daily total" entry per day
    /// (deterministic id so re-importing replaces rather than duplicates) plus its
    /// offset. Returns the number of days written.
    @discardableResult
    public static func apply(_ days: [ImportedDay], to store: any NutritionStoring) async -> Int {
        for day in days {
            let entry = Entry(
                id: "import-\(day.date)",
                date: day.date,
                timestamp: midnight(for: day.date),
                food: "Imported daily total",
                quantity: 1, unit: "serving",
                kcal: day.calories, fat: day.fat, carbs: day.carbs, protein: day.protein,
                method: .text
            )
            try? await store.add(entry)
            if day.offset > 0 { try? await store.setOffset(day.offset, on: day.date) }
        }
        return days.count
    }

    // MARK: - Helpers

    static func isValidDateKey(_ s: String) -> Bool {
        let parts = s.split(separator: "-", omittingEmptySubsequences: false)
        return parts.count == 3 && parts[0].count == 4 && parts.allSatisfy { !$0.isEmpty && $0.allSatisfy(\.isNumber) }
    }

    static func midnight(for key: String) -> Date {
        let parts = key.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return Date(timeIntervalSince1970: 0) }
        var components = DateComponents()
        components.year = parts[0]; components.month = parts[1]; components.day = parts[2]; components.hour = 12
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC") ?? .current
        return cal.date(from: components) ?? Date(timeIntervalSince1970: 0)
    }
}
