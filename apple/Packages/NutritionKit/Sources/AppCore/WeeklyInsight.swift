// WeeklyInsight — the calm "this week" observations above History's charts.
//
// Honest and never moral: it states what happened (days logged, net vs goal,
// protein) without "good/bad/failed/overate". A low week caused mostly by exercise
// offsets is attributed to the offsets, not to eating less. Pure selection from the
// range's DayTotals so the copy is unit-tested (including the no-judgment rule).

import Foundation
import NutritionCore

public struct WeeklyInsight: Sendable, Equatable {
    /// Ordered observation lines (plain, non-moral). Empty when nothing was logged.
    public let lines: [String]

    public init(lines: [String]) { self.lines = lines }

    public static func from(days: [DayTotals], targets: MacroTargets) -> WeeklyInsight {
        let logged = days.filter { $0.totals.calories > 0 }
        let n = logged.count
        guard n > 0 else { return WeeklyInsight(lines: []) }

        var lines: [String] = []

        // 1. Consistency.
        if n == days.count {
            lines.append("You logged every one of the \(days.count) days.")
        } else {
            lines.append("You logged \(n) of \(days.count) days.")
        }

        // 2. Calories — net vs goal, crediting exercise offsets when they dominate.
        let avgNet = logged.reduce(0) { $0 + $1.netCalories } / Double(n)
        let avgOffset = logged.reduce(0) { $0 + $1.offset } / Double(n)
        let goal = targets.calories
        if goal > 0 {
            let delta = avgNet - goal   // negative = under goal
            if delta < -20 {
                if avgOffset > 0, avgOffset >= -delta {
                    // Without the offsets you'd be at/over goal — so it's the workouts.
                    lines.append("Your net calories averaged \(Int(avgNet)) — lower mostly from workout offsets.")
                } else {
                    lines.append("Your net calories averaged \(Int(avgNet)), about \(Int(-delta)) under your goal.")
                }
            } else if delta > 20 {
                lines.append("Your net calories averaged \(Int(avgNet)), about \(Int(delta)) above your goal.")
            } else {
                lines.append("Your net calories averaged \(Int(avgNet)), right around your goal.")
            }
        }

        // 3. Protein.
        if targets.protein > 0 {
            let short = logged.filter { $0.totals.protein < targets.protein }.count
            if short == 0 {
                lines.append("Protein reached your \(Int(targets.protein))g target every logged day.")
            } else {
                let avgProtein = logged.reduce(0) { $0 + $1.totals.protein } / Double(n)
                lines.append("Protein averaged \(Int(avgProtein))g, under target on \(short) of \(n) days.")
            }
        }

        return WeeklyInsight(lines: lines)
    }
}
