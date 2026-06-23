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
        guard let headerLine = lines.first else { return ImportResult(entries: [], offsets: [:]) }
        // Map by column NAME so old files (no fiber/sodium/sugar) and new ones both
        // import, regardless of column order. Missing/blank cells → nil (not 0).
        let cols = columnIndex(headerLine)
        var entries: [Entry] = []
        var offsets: [String: Double] = [:]
        for line in lines.dropFirst() {
            let f = CSV.split(line)
            func field(_ name: String) -> String {
                guard let i = cols[name], i < f.count else { return "" }
                return f[i]
            }
            func num(_ name: String) -> Double? {
                let s = field(name).trimmingCharacters(in: .whitespaces)
                return s.isEmpty ? nil : Double(s)
            }
            let date = field("date")
            guard isValidDateKey(date) else { continue }
            let time = field("time"), food = field("food")
            let methodRaw = field("method").lowercased()

            if methodRaw == "offset" {
                if let cal = num("calories"), cal > 0 { offsets[date] = cal }
                continue
            }
            entries.append(Entry(
                id: "import-\(date)-\(time)-\(food)",
                date: date,
                timestamp: timestamp(date: date, time: time),
                food: food,
                quantity: num("quantity") ?? 0,
                unit: field("unit"),
                kcal: num("calories") ?? 0,
                fat: num("fat") ?? 0,
                carbs: num("carbs") ?? 0,
                protein: num("protein") ?? 0,
                method: InputMethod(rawValue: methodRaw) ?? .text,
                fiber: num("fiber"),       // nil when the column is absent or blank
                sodium: num("sodium"),     // milligrams
                sugar: num("sugar")
            ))
        }
        return ImportResult(entries: entries, offsets: offsets)
    }

    /// `[lowercased column name: index]` from the header row.
    private static func columnIndex(_ header: String) -> [String: Int] {
        var map: [String: Int] = [:]
        for (i, name) in CSV.split(header).enumerated() {
            map[name.trimmingCharacters(in: .whitespaces).lowercased()] = i
        }
        return map
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
