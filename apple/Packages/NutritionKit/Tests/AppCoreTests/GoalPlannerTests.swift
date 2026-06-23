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

    @Test("maintain targets sit near TDEE with sensible macros")
    func maintainTargets() {
        let t = GoalPlanner.targets(for: male)
        #expect(t.calories == 2759)             // round(2759.0)
        #expect(t.protein == 128)               // 80 × 1.6
        #expect(t.fat == 83)                    // round(2759 × 0.27 / 9)
        // carbs fill the remainder: (2759 - 128*4 - 83*9)/4 = 375
        #expect(t.carbs == 375)
    }

    @Test("a deficit goal lowers calories and raises protein per kg")
    func deficitGoal() {
        var p = male; p.goal = .steadyLoss
        let t = GoalPlanner.targets(for: p)
        #expect(t.calories == 2259)             // 2759 - 500
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
        #expect(GoalPlanner.targets(for: p).calories == 2759 + 350)
    }
}
