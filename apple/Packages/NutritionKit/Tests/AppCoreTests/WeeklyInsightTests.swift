// WeeklyInsight: the calm, non-moral observations shown above History's charts.
// Pure selection from the range's day totals, so the copy (and its no-judgment
// rule) is unit-tested.

import Testing
import Foundation
@testable import AppCore
import NutritionCore

@Suite("WeeklyInsight")
struct WeeklyInsightTests {

    private func day(_ date: String, kcal: Double, protein: Double = 0, offset: Double = 0) -> DayTotals {
        DayTotals(date: date, totals: MacroTotals(calories: kcal, fat: 0, carbs: 0, protein: protein), offset: offset)
    }

    private let targets = MacroTargets(calories: 2000, fat: 60, carbs: 200, protein: 120)

    @Test("reports how many of the range's days were logged")
    func loggedDays() {
        let days = (1...7).map { day("2026-06-0\($0)", kcal: $0 == 7 ? 0 : 1500, protein: 130) }  // 6 of 7
        let insight = WeeklyInsight.from(days: days, targets: targets)
        #expect(insight.lines.first == "You logged 6 of 7 days.")
    }

    @Test("attributes a low net to workout offsets when the offset dominates the gap")
    func offsetDominated() {
        // Food ≈ goal, but a big daily offset pulls net well under.
        let days = (1...3).map { day("2026-06-0\($0)", kcal: 2000, protein: 130, offset: 400) }
        let insight = WeeklyInsight.from(days: days, targets: targets)
        #expect(insight.lines.contains { $0.contains("workout offsets") })
    }

    @Test("a plain under-goal week (no offsets) is stated factually, not blamed on exercise")
    func underWithoutOffsets() {
        let days = (1...3).map { day("2026-06-0\($0)", kcal: 1500, protein: 130, offset: 0) }
        let insight = WeeklyInsight.from(days: days, targets: targets)
        #expect(insight.lines.contains { $0.contains("under your goal") })
        #expect(!insight.lines.contains { $0.contains("workout offsets") })
    }

    @Test("protein observation reflects target days")
    func protein() {
        let hit = (1...3).map { day("2026-06-0\($0)", kcal: 1800, protein: 130) }
        #expect(WeeklyInsight.from(days: hit, targets: targets).lines.contains { $0.contains("every logged day") })

        let short = (1...3).map { day("2026-06-0\($0)", kcal: 1800, protein: 80) }
        #expect(WeeklyInsight.from(days: short, targets: targets).lines.contains { $0.contains("under target") })
    }

    @Test("no entries → no lines")
    func empty() {
        #expect(WeeklyInsight.from(days: [], targets: targets).lines.isEmpty)
        #expect(WeeklyInsight.from(days: [day("2026-06-01", kcal: 0)], targets: targets).lines.isEmpty)
    }

    @Test("the copy never moralizes")
    func noMoralLanguage() {
        let banned = ["bad", "fail", "overate", "over-ate", "poorly", "lazy", "cheat",
                      "binge", "guilt", "shame", "should have", "gluttony", "good job", "well done"]
        // Exercise a spread of scenarios.
        let scenarios: [[DayTotals]] = [
            (1...7).map { day("2026-06-0\($0)", kcal: 1500, protein: 130, offset: 0) },
            (1...7).map { day("2026-06-0\($0)", kcal: 2600, protein: 80, offset: 0) },   // over goal, low protein
            (1...7).map { day("2026-06-0\($0)", kcal: 2000, protein: 130, offset: 500) },
        ]
        for days in scenarios {
            for line in WeeklyInsight.from(days: days, targets: targets).lines {
                let lower = line.lowercased()
                for word in banned { #expect(!lower.contains(word), "‘\(word)’ in: \(line)") }
            }
        }
    }
}
