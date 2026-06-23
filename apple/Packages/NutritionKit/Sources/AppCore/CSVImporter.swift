// Import of a CalorieCounter CSV. Auto-detects the format from the header:
//   • Full per-entry export (date,time,food,…,method) → restores every food and
//     each day's offset exactly.
//   • Legacy daily-totals export (date,calories_consumed,…) → restores one
//     "Imported daily total" row per day (the old format has no individual foods).
// Pure parsing + a store-apply, both unit-tested.

import Foundation
import NutritionCore

public struct ImportResult: Sendable, Equatable {
    public let entries: [Entry]
    public let offsets: [String: Double]

    /// Distinct days covered (entries or offsets).
    public var dayCount: Int { Set(entries.map(\.date)).union(offsets.keys).count }
}

public enum CSVImporter {
    public enum ImportError: Error, Equatable {
        case unrecognizedFormat   // not a CalorieCounter CSV
        case noRows               // header ok but no usable data
    }

    /// Parse a CalorieCounter CSV, auto-detecting the format.
    public static func parse(_ csv: String) throws -> ImportResult {
        let lines = csv.split(whereSeparator: \.isNewline).map(String.init)
        guard let header = lines.first else { throw ImportError.unrecognizedFormat }
        let normalized = header.replacingOccurrences(of: " ", with: "").lowercased()

        let result: ImportResult
        if normalized.hasPrefix("date,time,food") {
            result = parsePerEntry(lines)
        } else if normalized.hasPrefix("date,calories_consumed,calories_burned") {
            result = parseDailyTotals(lines)
        } else {
            throw ImportError.unrecognizedFormat
        }

        guard !result.entries.isEmpty || !result.offsets.isEmpty else { throw ImportError.noRows }
        return result
    }

    /// Persist a parsed import: every entry (deterministic ids so re-importing
    /// replaces, not duplicates) plus each day's offset. Returns the day count.
    @discardableResult
    public static func apply(_ result: ImportResult, to store: any NutritionStoring) async -> Int {
        for entry in result.entries { try? await store.add(entry) }
        for (date, value) in result.offsets { try? await store.setOffset(value, on: date) }
        return result.dayCount
    }

    // MARK: - Per-entry format

    private static func parsePerEntry(_ lines: [String]) -> ImportResult {
        var entries: [Entry] = []
        var offsets: [String: Double] = [:]
        for line in lines.dropFirst() {
            let f = CSV.split(line)
            guard f.count >= 10, isValidDateKey(f[0]) else { continue }
            let date = f[0], time = f[1], food = f[2]
            let kcal = Double(f[5]) ?? 0
            let methodRaw = f[9].lowercased()

            if methodRaw == "offset" {
                if kcal > 0 { offsets[date] = kcal }
                continue
            }
            entries.append(Entry(
                id: "import-\(date)-\(time)-\(food)",
                date: date,
                timestamp: timestamp(date: date, time: time),
                food: food,
                quantity: Double(f[3]) ?? 0,
                unit: f[4],
                kcal: kcal,
                fat: Double(f[6]) ?? 0,
                carbs: Double(f[7]) ?? 0,
                protein: Double(f[8]) ?? 0,
                method: InputMethod(rawValue: methodRaw) ?? .text
            ))
        }
        return ImportResult(entries: entries, offsets: offsets)
    }

    // MARK: - Legacy daily-totals format

    private static func parseDailyTotals(_ lines: [String]) -> ImportResult {
        var entries: [Entry] = []
        var offsets: [String: Double] = [:]
        for line in lines.dropFirst() {
            let f = CSV.split(line)
            guard f.count >= 7, isValidDateKey(f[0]) else { continue }
            let date = f[0]
            entries.append(Entry(
                id: "import-\(date)",
                date: date,
                timestamp: midnight(for: date),
                food: "Imported daily total",
                quantity: 1, unit: "serving",
                kcal: Double(f[1]) ?? 0,
                fat: Double(f[5]) ?? 0,
                carbs: Double(f[4]) ?? 0,
                protein: Double(f[6]) ?? 0,
                method: .text
            ))
            if let burned = Double(f[2]), burned > 0 { offsets[date] = burned }
        }
        return ImportResult(entries: entries, offsets: offsets)
    }

    // MARK: - Helpers

    static func isValidDateKey(_ s: String) -> Bool {
        let parts = s.split(separator: "-", omittingEmptySubsequences: false)
        return parts.count == 3 && parts[0].count == 4 && parts.allSatisfy { !$0.isEmpty && $0.allSatisfy(\.isNumber) }
    }

    private static var utcCalendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC") ?? .current
        return cal
    }

    static func midnight(for key: String) -> Date {
        timestamp(date: key, time: "12:00")
    }

    static func timestamp(date key: String, time: String) -> Date {
        let dateParts = key.split(separator: "-").compactMap { Int($0) }
        let timeParts = time.split(separator: ":").compactMap { Int($0) }
        guard dateParts.count == 3 else { return Date(timeIntervalSince1970: 0) }
        var components = DateComponents()
        components.year = dateParts[0]; components.month = dateParts[1]; components.day = dateParts[2]
        components.hour = timeParts.first ?? 12
        components.minute = timeParts.count > 1 ? timeParts[1] : 0
        return utcCalendar.date(from: components) ?? Date(timeIntervalSince1970: 0)
    }
}
