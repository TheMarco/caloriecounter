// CSV export of daily nutrition, ported byte-for-byte from `src/utils/csvExport.ts`:
//   header: date,calories_consumed,calories_burned,net_calories,carbs,fat,protein
//   rows:   only days with any food or an offset; macros to 1 decimal; net =
//           max(0, calories − offset). Pure, so it's fully unit-tested.

import Foundation
import NutritionCore

public enum CSVExporter {
    public static let header = "date,calories_consumed,calories_burned,net_calories,carbs,fat,protein"

    /// Build the CSV text for the given daily rows (oldest-first from the store).
    public static func csv(from days: [DayTotals]) -> String {
        let rows = days.filter(hasData).map(row(for:))
        return ([header] + rows).joined(separator: "\n")
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
}
