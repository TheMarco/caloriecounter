//
//  OnboardingUITests.swift
//  Verifies the reordered onboarding "trust ritual": the app earns trust (welcome)
//  and shows a no-stakes demo (Try a Meal) BEFORE asking for any body data (Your
//  Goal). Launched with `-uitest -onboarding`: in-memory store, deterministic, and
//  the wizard forced on even though -uitest normally suppresses it.
//

import XCTest

final class OnboardingUITests: XCTestCase {

    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    func testTrustComesBeforeBodyData() {
        let app = XCUIApplication()
        app.launchArguments += ["-uitest", "-onboarding"]
        app.launch()

        // Step 1 — Welcome (the trust promise).
        XCTAssertTrue(app.staticTexts["Welcome"].waitForExistence(timeout: 10),
                      "Onboarding should open on the Welcome trust step")

        // Continue → Step 2 — Try a Meal (the canned MealCard demo).
        app.buttons["Continue"].tap()
        XCTAssertTrue(app.staticTexts["Try a Meal"].waitForExistence(timeout: 5),
                      "Welcome should advance to the 'Try a Meal' demo, not straight to a form")
        // The demo renders the real meal card with its honest copy.
        XCTAssertTrue(app.staticTexts["Banana"].waitForExistence(timeout: 5),
                      "The demo should reveal the canned meal card")

        // Continue → Step 3 — Your Goal (the first time we ask for anything).
        app.buttons["Continue"].tap()
        XCTAssertTrue(app.staticTexts["Your Goal"].waitForExistence(timeout: 5),
                      "Only after trust + demo do we ask for the goal")
    }
}
