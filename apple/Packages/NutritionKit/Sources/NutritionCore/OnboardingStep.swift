// OnboardingStep — the wizard's ordered steps and its one piece of gating logic.
//
// The order encodes the product decision that onboarding earns trust *before* it
// asks for body data: the privacy promise (welcome) and a no-stakes taste of
// logging (tryMeal) come first, then goal → diet → body → activity → plan. Kept in
// NutritionCore (SwiftUI-free) so the sequence and the goal-required gate are unit
// tested; the view renders each step and is verified by screenshot.

import Foundation

public enum OnboardingStep: Int, CaseIterable, Sendable {
    case welcome     // privacy / trust promise
    case tryMeal     // a canned MealCard demo — "this is logging"
    case goal        // weight goal (the one required choice)
    case diet        // diet style
    case body        // sex / age / weight / height
    case activity    // activity level
    case plan        // computed targets

    public static var count: Int { allCases.count }

    /// Continue is blocked on this step until the user makes a choice. Only the
    /// goal step gates — everything else has a sensible default.
    public var requiresGoal: Bool { self == .goal }

    /// The header title for this step.
    public var title: String {
        switch self {
        case .welcome:  return "Welcome"
        case .tryMeal:  return "Try a Meal"
        case .goal:     return "Your Goal"
        case .diet:     return "Diet Style"
        case .body:     return "About You"
        case .activity: return "Activity"
        case .plan:     return "Your Plan"
        }
    }
}
