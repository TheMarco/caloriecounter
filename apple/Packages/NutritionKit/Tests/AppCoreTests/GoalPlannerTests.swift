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

    @Test("maintain targets sit near TDEE, rounded to tidy increments")
    func maintainTargets() {
        let t = GoalPlanner.targets(for: male)
        #expect(t.calories == 2750)             // round(2759, nearest 25)
        #expect(t.protein == 130)               // round(80 × 1.6 = 128, nearest 5)
        #expect(t.fat == 85)                    // round(2750 × 0.27 / 9 = 82.5, nearest 5)
        // carbs fill the remainder: round((2750 - 130*4 - 85*9)/4 = 366.25, nearest 5)
        #expect(t.carbs == 365)
    }

    @Test("a deficit goal lowers calories and raises protein per kg")
    func deficitGoal() {
        var p = male; p.goal = .steadyLoss
        let t = GoalPlanner.targets(for: p)
        #expect(t.calories == 2250)             // round(2759 - 500 = 2259, nearest 25)
        #expect(t.protein == 160)               // 80 × 2.0
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

    @Test("targets are always tidy multiples (calories/25, macros/5) for every goal")
    func tidyMultiples() {
        for goal in WeightGoal.allCases {
            var p = male; p.goal = goal
            let t = GoalPlanner.targets(for: p)
            #expect(t.calories.truncatingRemainder(dividingBy: 25) == 0)
            #expect(t.fat.truncatingRemainder(dividingBy: 5) == 0)
            #expect(t.carbs.truncatingRemainder(dividingBy: 5) == 0)
            #expect(t.protein.truncatingRemainder(dividingBy: 5) == 0)
        }
    }
}
