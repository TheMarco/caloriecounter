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
}

/// How the day's calories are split across macros. The weight goal sets *how
/// much* you eat; the diet style sets *what* it's made of — so people can run
/// balanced, high-protein, low-carb, keto, high-carb, or Mediterranean.
public enum DietStyle: String, CaseIterable, Sendable, Identifiable {
    case balanced, highProtein, lowCarb, keto, highCarb, mediterranean
    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .balanced: return "Balanced"
        case .highProtein: return "High Protein"
        case .lowCarb: return "Low Carb"
        case .keto: return "Keto"
        case .highCarb: return "High Carb"
        case .mediterranean: return "Mediterranean"
        }
    }
    public var detail: String {
        switch self {
        case .balanced: return "An even mix of carbs, protein, and fat"
        case .highProtein: return "More protein to build and keep muscle"
        case .lowCarb: return "Fewer carbs, more fat and protein"
        case .keto: return "Very low carb, high fat"
        case .highCarb: return "Carb-forward for endurance and big training days"
        case .mediterranean: return "Whole foods with plenty of healthy fats"
        }
    }
    public var systemImage: String {
        switch self {
        case .balanced: return "fork.knife"
        case .highProtein: return "dumbbell.fill"
        case .lowCarb: return "leaf.fill"
        case .keto: return "drop.fill"
        case .highCarb: return "bolt.fill"
        case .mediterranean: return "sun.max.fill"
        }
    }
    /// Macro split as fractions of total calories — (protein, carbs, fat), sums to 1.
    public var split: (protein: Double, carbs: Double, fat: Double) {
        switch self {
        case .balanced:      return (0.30, 0.40, 0.30)
        case .highProtein:   return (0.40, 0.30, 0.30)
        case .lowCarb:       return (0.35, 0.20, 0.45)
        case .keto:          return (0.25, 0.05, 0.70)
        case .highCarb:      return (0.25, 0.55, 0.20)
        case .mediterranean: return (0.25, 0.45, 0.30)
        }
    }
    /// Compact split label, e.g. "40% C · 30% P · 30% F".
    public var splitLabel: String {
        let s = split
        return "\(Int(s.carbs * 100))% C · \(Int(s.protein * 100))% P · \(Int(s.fat * 100))% F"
    }
}

public struct UserProfile: Sendable, Equatable {
    public var sex: BiologicalSex
    public var age: Int
    public var weightKg: Double
    public var heightCm: Double
    public var activity: ActivityLevel
    public var goal: WeightGoal
    public var dietStyle: DietStyle

    public init(sex: BiologicalSex, age: Int, weightKg: Double, heightCm: Double,
                activity: ActivityLevel, goal: WeightGoal, dietStyle: DietStyle = .balanced) {
        self.sex = sex; self.age = age; self.weightKg = weightKg
        self.heightCm = heightCm; self.activity = activity; self.goal = goal
        self.dietStyle = dietStyle
    }
}

public enum GoalPlanner {
    /// A floor so aggressive deficits never recommend an unsafe intake.
    static let minimumCalories: Double = 1200

    /// Mifflin-St Jeor basal metabolic rate (kcal/day).
    public static func bmr(_ p: UserProfile) -> Double {
        let base = 10 * p.weightKg + 6.25 * p.heightCm - 5 * Double(p.age)
        return base + (p.sex == .male ? 5 : -161)
    }

    /// Total daily energy expenditure (BMR × activity).
    public static func tdee(_ p: UserProfile) -> Double {
        bmr(p) * p.activity.factor
    }

    /// Recommended daily targets for the profile. The weight goal sets calories
    /// (TDEE + delta); the diet style splits those calories across macros. Values
    /// are rounded to tidy increments (calories to 25, macros to 5) so the plan
    /// reads like a goal a person would set, not a raw calculation.
    public static func targets(for p: UserProfile) -> MacroTargets {
        let calories = round(max(minimumCalories, tdee(p) + p.goal.calorieDelta), toNearest: 25)
        let s = p.dietStyle.split
        let protein = round(calories * s.protein / 4, toNearest: 5)   // 4 kcal/g
        let fat = round(calories * s.fat / 9, toNearest: 5)           // 9 kcal/g
        let carbs = round(calories * s.carbs / 4, toNearest: 5)       // 4 kcal/g
        return MacroTargets(calories: calories, fat: fat, carbs: carbs, protein: protein).clamped
    }

    /// Round to the nearest `step` (e.g. nearest 25 kcal).
    static func round(_ value: Double, toNearest step: Double) -> Double {
        (value / step).rounded() * step
    }
}
