// GoalPlanner: BMR/TDEE math and goal-adjusted targets.

import Testing
@testable import AppCore
import NutritionCore

@Suite("GoalPlanner")
struct GoalPlannerTests {

    private let male = UserProfile(sex: .male, age: 30, weightKg: 80, heightCm: 180,
                                   activity: .moderate, goal: .maintain)

    @Test("Mifflin-St Jeor BMR matches the formula for both sexes")
    func bmr() {
        // 10*80 + 6.25*180 - 5*30 + 5 = 1780
        #expect(GoalPlanner.bmr(male) == 1780)
        var female = male; female.sex = .female
        // same minus 166 (5 - (-161))
        #expect(GoalPlanner.bmr(female) == 1614)
    }

    @Test("TDEE applies the activity factor")
    func tdee() {
        #expect(GoalPlanner.tdee(male) == 1780 * 1.55)   // 2759
    }

    @Test("maintain + balanced splits TDEE across macros, rounded")
    func maintainTargets() {
        let t = GoalPlanner.targets(for: male)   // dietStyle defaults to .balanced (30/40/30)
        #expect(t.calories == 2750)              // round(2759, nearest 25)
        #expect(t.protein == 205)                // round(2750 × 0.30 / 4 = 206.25, nearest 5)
        #expect(t.fat == 90)                     // round(2750 × 0.30 / 9 = 91.67, nearest 5)
        #expect(t.carbs == 275)                  // round(2750 × 0.40 / 4 = 275, nearest 5)
    }

    @Test("a deficit goal lowers calories; the diet style still drives the split")
    func deficitGoal() {
        var p = male; p.goal = .steadyLoss
        let t = GoalPlanner.targets(for: p)
        #expect(t.calories == 2250)              // round(2759 - 500 = 2259, nearest 25)
        #expect(t.protein == 170)                // round(2250 × 0.30 / 4 = 168.75, nearest 5)
    }

    @Test("diet style changes the split — keto cuts carbs and raises fat at the same calories")
    func dietStyleSplits() {
        let balanced = GoalPlanner.targets(for: male)
        var k = male; k.dietStyle = .keto
        let keto = GoalPlanner.targets(for: k)
        #expect(keto.calories == balanced.calories)   // same energy, different macros
        #expect(keto.carbs < balanced.carbs)
        #expect(keto.fat > balanced.fat)
        #expect(keto.carbs == 35)                     // round(2750 × 0.05 / 4, 5) — needs the widened floor
        #expect(keto.fat == 215)                      // round(2750 × 0.70 / 9, 5) — needs the widened ceiling
    }

    @Test("every diet style's macro split sums to 100%")
    func splitsSumToOne() {
        for style in DietStyle.allCases {
            let s = style.split
            #expect(abs(s.protein + s.carbs + s.fat - 1.0) < 0.0001)
        }
    }

    @Test("an aggressive deficit never drops below the safe calorie floor")
    func safetyFloor() {
        let small = UserProfile(sex: .female, age: 60, weightKg: 50, heightCm: 155,
                                activity: .sedentary, goal: .radicalLoss)
        // TDEE ≈ (10*50 + 6.25*155 - 5*60 - 161) × 1.2 = 1004.7; −750 would be negative.
        #expect(GoalPlanner.targets(for: small).calories == 1200)
    }

    @Test("gain goal adds a surplus")
    func gainGoal() {
        var p = male; p.goal = .gain
        #expect(GoalPlanner.targets(for: p).calories == 3100)   // round(2759 + 350 = 3109, nearest 25)
    }

    @Test("targets are always tidy multiples (calories/25, macros/5) for every goal and diet")
    func tidyMultiples() {
        for goal in WeightGoal.allCases {
            for style in DietStyle.allCases {
                var p = male; p.goal = goal; p.dietStyle = style
                let t = GoalPlanner.targets(for: p)
                #expect(t.calories.truncatingRemainder(dividingBy: 25) == 0)
                #expect(t.fat.truncatingRemainder(dividingBy: 5) == 0)
                #expect(t.carbs.truncatingRemainder(dividingBy: 5) == 0)
                #expect(t.protein.truncatingRemainder(dividingBy: 5) == 0)
            }
        }
    }
}
