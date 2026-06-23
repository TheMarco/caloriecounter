// Turns a body profile + a weight goal into daily calorie & macro targets.
// Calories: Mifflin-St Jeor BMR × an activity factor (TDEE), then a goal delta.
// Protein scales with bodyweight (more on a deficit to preserve muscle); fat is a
// share of calories; carbs fill the rest. Pure and unit-tested.

import Foundation
import NutritionCore

public enum BiologicalSex: String, CaseIterable, Sendable, Identifiable {
    case male, female
    public var id: String { rawValue }
    public var label: String { self == .male ? "Male" : "Female" }
}

public enum ActivityLevel: String, CaseIterable, Sendable, Identifiable {
    case sedentary, light, moderate, active, veryActive
    public var id: String { rawValue }

    public var factor: Double {
        switch self {
        case .sedentary: return 1.2
        case .light: return 1.375
        case .moderate: return 1.55
        case .active: return 1.725
        case .veryActive: return 1.9
        }
    }
    public var label: String {
        switch self {
        case .sedentary: return "Sedentary"
        case .light: return "Lightly active"
        case .moderate: return "Moderately active"
        case .active: return "Very active"
        case .veryActive: return "Extremely active"
        }
    }
    public var detail: String {
        switch self {
        case .sedentary: return "Little or no exercise, desk job"
        case .light: return "Light exercise 1–3 days/week"
        case .moderate: return "Moderate exercise 3–5 days/week"
        case .active: return "Hard exercise 6–7 days/week"
        case .veryActive: return "Athlete or very physical job"
        }
    }
}

public enum WeightGoal: String, CaseIterable, Sendable, Identifiable {
    case radicalLoss, steadyLoss, maintain, gain
    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .radicalLoss: return "Lose weight fast"
        case .steadyLoss: return "Lose slow & steady"
        case .maintain: return "Maintain weight"
        case .gain: return "Gain responsibly"
        }
    }
    public var detail: String {
        switch self {
        case .radicalLoss: return "About 0.75 kg (1.5 lb) per week"
        case .steadyLoss: return "About 0.5 kg (1 lb) per week"
        case .maintain: return "Keep your current weight"
        case .gain: return "About 0.25 kg (0.5 lb) per week"
        }
    }
    public var systemImage: String {
        switch self {
        case .radicalLoss: return "flame.fill"
        case .steadyLoss: return "figure.walk"
        case .maintain: return "equal.circle.fill"
        case .gain: return "arrow.up.heart.fill"
        }
    }
    /// Daily calorie delta from maintenance.
    public var calorieDelta: Double {
        switch self {
        case .radicalLoss: return -750
        case .steadyLoss: return -500
        case .maintain: return 0
        case .gain: return 350
        }
    }
    /// Grams of protein per kg of bodyweight (higher on a deficit).
    public var proteinPerKg: Double {
        switch self {
        case .radicalLoss, .steadyLoss: return 2.0
        case .maintain: return 1.6
        case .gain: return 1.8
        }
    }
}

public struct UserProfile: Sendable, Equatable {
    public var sex: BiologicalSex
    public var age: Int
    public var weightKg: Double
    public var heightCm: Double
    public var activity: ActivityLevel
    public var goal: WeightGoal

    public init(sex: BiologicalSex, age: Int, weightKg: Double, heightCm: Double,
                activity: ActivityLevel, goal: WeightGoal) {
        self.sex = sex; self.age = age; self.weightKg = weightKg
        self.heightCm = heightCm; self.activity = activity; self.goal = goal
    }
}

public enum GoalPlanner {
    /// A floor so aggressive deficits never recommend an unsafe intake.
    static let minimumCalories: Double = 1200
    /// Fat as a share of total calories.
    static let fatCaloriePortion = 0.27

    /// Mifflin-St Jeor basal metabolic rate (kcal/day).
    public static func bmr(_ p: UserProfile) -> Double {
        let base = 10 * p.weightKg + 6.25 * p.heightCm - 5 * Double(p.age)
        return base + (p.sex == .male ? 5 : -161)
    }

    /// Total daily energy expenditure (BMR × activity).
    public static func tdee(_ p: UserProfile) -> Double {
        bmr(p) * p.activity.factor
    }

    /// Recommended daily targets for the profile + goal, clamped to valid ranges.
    public static func targets(for p: UserProfile) -> MacroTargets {
        let calories = max(minimumCalories, (tdee(p) + p.goal.calorieDelta).rounded())
        let protein = (p.weightKg * p.goal.proteinPerKg).rounded()
        let fat = (calories * fatCaloriePortion / 9).rounded()
        let carbs = max(0, ((calories - protein * 4 - fat * 9) / 4).rounded())
        return MacroTargets(calories: calories, fat: fat, carbs: carbs, protein: protein).clamped
    }
}
