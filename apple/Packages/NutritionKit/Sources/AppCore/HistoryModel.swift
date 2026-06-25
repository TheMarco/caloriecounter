// View model + pure helpers for the History screen. In AppCore so the daily-rows
// loading, the per-macro chart series (with target coloring), and the calendar
// month layout are unit-tested independently of Swift Charts / the calendar UI.

import Foundation
import Observation
import NutritionCore

/// Which macro a chart/series is showing.
public enum MacroKind: String, CaseIterable, Sendable, Identifiable {
    case calories, fat, carbs, protein
    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .calories: return "Calories"
        case .fat: return "Fat"
        case .carbs: return "Carbs"
        case .protein: return "Protein"
        }
    }
    public var unit: String { self == .calories ? "kcal" : "g" }

    public func value(in totals: MacroTotals) -> Double {
        switch self {
        case .calories: return totals.calories
        case .fat: return totals.fat
        case .carbs: return totals.carbs
        case .protein: return totals.protein
        }
    }
    public func target(in targets: MacroTargets) -> Double {
        switch self {
        case .calories: return targets.calories
        case .fat: return targets.fat
        case .carbs: return targets.carbs
        case .protein: return targets.protein
        }
    }
}

/// One plotted point: a local day, its macro value, and whether it exceeds target.
public struct MacroSeriesPoint: Sendable, Equatable, Identifiable {
    public let date: String
    public let value: Double
    public let isOverTarget: Bool
    public var id: String { date }
}

/// One weight measurement for the chart (canonical kilograms; view converts).
public struct WeightPoint: Sendable, Equatable, Identifiable {
    public let date: String
    public let weightKg: Double
    public var id: String { date }
}

/// At-a-glance numbers for the History "Insights" card, computed purely over the
/// loaded range so it's unit-tested without the chart UI. Averages cover only the
/// days that were actually logged — a blank day shouldn't drag the average down.
public struct RangeInsights: Sendable, Equatable {
    public let loggedDays: Int
    public let totalDays: Int
    public let avgCalories: Double
    public let calorieGoal: Double
    public let avgProtein: Double
    public let proteinGoal: Double
    /// Logged days whose protein fell below target.
    public let proteinShortDays: Int

    public var hasData: Bool { loggedDays > 0 }
    /// Average daily calories minus the goal (negative = under goal).
    public var calorieDelta: Double { avgCalories - calorieGoal }

    public static func from(days: [DayTotals], targets: MacroTargets) -> RangeInsights {
        let logged = days.filter { $0.totals.calories > 0 }
        let n = logged.count
        func avg(_ value: (DayTotals) -> Double) -> Double {
            n > 0 ? logged.reduce(0) { $0 + value($1) } / Double(n) : 0
        }
        return RangeInsights(
            loggedDays: n,
            totalDays: days.count,
            // Net calories (food minus the day's exercise offset), matching Today.
            avgCalories: avg { $0.netCalories },
            calorieGoal: targets.calories,
            avgProtein: avg { $0.totals.protein },
            proteinGoal: targets.protein,
            proteinShortDays: logged.filter { $0.totals.protein < targets.protein }.count
        )
    }
}

@Observable
@MainActor
public final class HistoryModel {
    public var range: DateRange
    public private(set) var days: [DayTotals] = []
    public private(set) var weightPoints: [WeightPoint] = []
    public private(set) var latestWeightKg: Double?
    public private(set) var isLoading = false

    @ObservationIgnored private let store: any NutritionStoring

    public init(store: any NutritionStoring, range: DateRange = .week) {
        self.store = store
        self.range = range
    }

    public func load() async {
        isLoading = true
        defer { isLoading = false }
        let span = await dayCount(for: range)
        days = (try? await store.dailyTotals(lastDays: span)) ?? []

        // Weight measurements over the same window (one per day already).
        if let start = days.first?.date, let end = days.last?.date {
            let ws = (try? await store.weights(from: start, to: end)) ?? []
            weightPoints = ws.map { WeightPoint(date: $0.date, weightKg: $0.weightKg) }
        } else {
            weightPoints = []
        }
        latestWeightKg = (try? await store.latestWeight())?.weightKg
    }

    /// Days to load: the preset span, or — for `.all` — the inclusive span from the
    /// earliest logged day to today (falls back to a week when there's no data).
    private func dayCount(for range: DateRange) async -> Int {
        guard range.isAll else { return range.days }
        let today = LocalDate.today()
        let all = (try? await store.entries(from: "0001-01-01", to: today)) ?? []
        guard let earliest = all.map(\.date).min() else { return DateRange.week.days }
        return min(LocalDate.dayCount(from: earliest, to: today), range.days)
    }

    /// Per-day points for `macro`, flagged when over `targets` (chart coloring).
    public func series(_ macro: MacroKind, targets: MacroTargets) -> [MacroSeriesPoint] {
        days.map { day in
            // Calories track NET (food minus the day's exercise offset), matching
            // Today and MacroMath; the other macros aren't affected by offsets.
            let value = macro == .calories ? day.netCalories : macro.value(in: day.totals)
            return MacroSeriesPoint(date: day.date, value: value, isOverTarget: value > macro.target(in: targets))
        }
    }

    /// Local days within the loaded range that have any logged food (calendar dots).
    public var datesWithEntries: Set<String> {
        Set(days.filter { $0.totals.calories > 0 }.map(\.date))
    }

    /// Summary numbers for the Insights card over the currently-loaded range.
    public func insights(targets: MacroTargets) -> RangeInsights {
        RangeInsights.from(days: days, targets: targets)
    }
}

/// Pure month layout for the calendar grid (leading blanks + day count). A
/// `Calendar` is injected so tests are timezone/locale independent.
public struct CalendarMonth: Sendable, Equatable {
    public let year: Int
    public let month: Int
    public let dayCount: Int
    /// Empty cells before day 1, given the calendar's `firstWeekday`.
    public let leadingBlanks: Int

    public init?(year: Int, month: Int, calendar: Calendar = .current) {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = 1
        guard let firstOfMonth = calendar.date(from: components),
              let range = calendar.range(of: .day, in: .month, for: firstOfMonth) else { return nil }
        self.year = year
        self.month = month
        self.dayCount = range.count
        let weekday = calendar.component(.weekday, from: firstOfMonth)   // 1…7
        self.leadingBlanks = (weekday - calendar.firstWeekday + 7) % 7
    }

    /// `YYYY-MM-DD` for a day in this month.
    public func dateKey(day: Int) -> String {
        String(format: "%04d-%02d-%02d", year, month, day)
    }
}
