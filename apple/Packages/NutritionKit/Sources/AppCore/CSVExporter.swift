// CSV export of daily nutrition, ported byte-for-byte from `src/utils/csvExport.ts`:
//   header: date,calories_consumed,calories_burned,net_calories,carbs,fat,protein
//   rows:   only days with any food or an offset; macros to 1 decimal; net =
//           max(0, calories − offset). Pure, so it's fully unit-tested.

import Foundation
import NutritionCore

public enum CSVExporter {
    public static let header = "date,calories_consumed,calories_burned,net_calories,carbs,fat,protein"
    /// Full per-entry export header (one row per logged food). Fiber/sugar in
    /// grams, sodium in milligrams; blank when unknown.
    public static let entryHeader = "date,time,food,quantity,unit,calories,fat,carbs,protein,fiber,sodium,sugar,method"

    /// Build the daily-totals CSV (legacy/summary format).
    public static func csv(from days: [DayTotals]) -> String {
        let rows = days.filter(hasData).map(row(for:))
        return ([header] + rows).joined(separator: "\n")
    }

    /// Full export: one row per individual food (CSV-escaped name) plus one row per
    /// day-offset (`method` column = "offset"). Round-trips through CSVImporter, so
    /// it's a complete backup — every food is preserved, not just daily totals.
    public static func entriesCSV(entries: [Entry], offsets: [String: Double], weights: [WeightEntry] = []) -> String {
        var lines = [entryHeader]
        for e in entries.sorted(by: { $0.timestamp < $1.timestamp }) {
            lines.append([
                e.date,
                timeString(e.timestamp),
                CSV.escape(e.food),
                number(e.quantity),
                CSV.escape(e.unit),
                number(e.kcal),
                oneDecimal(e.fat),
                oneDecimal(e.carbs),
                oneDecimal(e.protein),
                optionalOneDecimal(e.fiber),   // grams, blank if unknown
                optionalNumber(e.sodium),      // milligrams, blank if unknown
                optionalOneDecimal(e.sugar),   // grams, blank if unknown
                e.method.rawValue,
            ].joined(separator: ","))
        }
        for (date, value) in offsets.sorted(by: { $0.key < $1.key }) where value > 0 {
            lines.append([date, "", "Exercise & Adjustment", "", "", number(value), "", "", "", "", "", "", "offset"]
                .joined(separator: ","))
        }
        // Body weight (kg in the quantity column) so the backup round-trips weigh-ins.
        for w in weights.sorted(by: { $0.date < $1.date }) {
            lines.append([w.date, timeString(w.timestamp), "Weight", oneDecimal(w.weightKg), "kg", "", "", "", "", "", "", "", "weight"]
                .joined(separator: ","))
        }
        return lines.joined(separator: "\n")
    }

    static func timeString(_ date: Date) -> String {
        let c = Calendar.current.dateComponents([.hour, .minute], from: date)
        return String(format: "%02d:%02d", c.hour ?? 0, c.minute ?? 0)
    }

    /// Default export filename: `calorie-counter-data-YYYY-MM-DD.csv`.
    public static func filename(today: String = LocalDate.today()) -> String {
        "calorie-counter-data-\(today).csv"
    }

    static func hasData(_ day: DayTotals) -> Bool {
        day.totals.calories > 0 || day.totals.fat > 0 || day.totals.carbs > 0
            || day.totals.protein > 0 || day.offset > 0
    }

    static func row(for day: DayTotals) -> String {
        let net = max(0, day.totals.calories - day.offset)
        return [
            day.date,
            number(day.totals.calories),
            number(day.offset),
            number(net),
            oneDecimal(day.totals.carbs),
            oneDecimal(day.totals.fat),
            oneDecimal(day.totals.protein),
        ].joined(separator: ",")
    }

    /// Whole numbers print without a decimal (matching JS number stringification).
    private static func number(_ value: Double) -> String {
        value == value.rounded() ? String(Int(value)) : String(value)
    }
    private static func oneDecimal(_ value: Double) -> String {
        String(format: "%.1f", value)
    }
    /// Empty string for unknown (nil), so blanks import back as nil (not 0).
    private static func optionalNumber(_ value: Double?) -> String { value.map(number) ?? "" }
    private static func optionalOneDecimal(_ value: Double?) -> String { value.map(oneDecimal) ?? "" }
}
