// OnboardingStep: the onboarding wizard's step order + gating, extracted from the
// view so the "trust before body data" sequence and the goal-required gate are
// locked by tests (the view is verified by screenshot).

import Testing
@testable import NutritionCore

@Suite("OnboardingStep")
struct OnboardingStepTests {

    @Test("there are seven steps")
    func sevenSteps() {
        #expect(OnboardingStep.count == 7)
        #expect(OnboardingStep.allCases.count == 7)
    }

    @Test("trust comes before body data: welcome → tryMeal → goal → diet → body → activity → plan")
    func order() {
        #expect(OnboardingStep.allCases == [
            .welcome, .tryMeal, .goal, .diet, .body, .activity, .plan
        ])
    }

    @Test("the goal step is third (index 2) and is the only one that requires a goal")
    func goalGating() {
        #expect(OnboardingStep.goal.rawValue == 2)
        #expect(OnboardingStep.goal.requiresGoal)
        for step in OnboardingStep.allCases where step != .goal {
            #expect(!step.requiresGoal)
        }
    }

    @Test("the demo step sits right after welcome, before any data entry")
    func tryMealIsSecond() {
        #expect(OnboardingStep.tryMeal.rawValue == 1)
        #expect(OnboardingStep.plan.rawValue == OnboardingStep.count - 1)
    }

    @Test("every step has a non-empty title")
    func titles() {
        for step in OnboardingStep.allCases {
            #expect(!step.title.isEmpty)
        }
        #expect(OnboardingStep.welcome.title == "Welcome")
        #expect(OnboardingStep.tryMeal.title == "Try a Meal")
    }
}
