//
//  SettingsUITests.swift
//  Smoke tests for Settings — now reached via the top-right gear (it's no longer a
//  tab). `-screen-settings` opens the Settings sheet straight away; one test taps
//  the gear itself to prove that entry point.
//

import XCTest

final class SettingsUITests: XCTestCase {

    override func setUp() { continueAfterFailure = false }

    /// Launch with the Settings sheet already open.
    private func launchInSettings() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-uitest", "-screen-settings"]
        app.launch()
        return app
    }

    /// Advance the setup wizard from its first step (Welcome) to the Goal step.
    private func advanceToGoal(_ app: XCUIApplication) {
        XCTAssertTrue(app.staticTexts["Welcome"].waitForExistence(timeout: 5), "Wizard opens on Welcome")
        app.buttons["Continue"].tap()                                   // → Try a Meal
        XCTAssertTrue(app.staticTexts["Try a Meal"].waitForExistence(timeout: 5))
        app.buttons["Continue"].tap()                                   // → Your Goal
        XCTAssertTrue(app.staticTexts["Your Goal"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testSettingsGearOpensSettings() {
        let app = XCUIApplication()
        app.launchArguments += ["-uitest"]
        app.launch()

        let gear = app.buttons["Settings"]
        XCTAssertTrue(gear.waitForExistence(timeout: 10), "A Settings gear should exist on Today")
        gear.tap()
        XCTAssertTrue(app.staticTexts["Daily Targets"].waitForExistence(timeout: 5), "Gear opens Settings")
    }

    @MainActor
    func testSettingsRenders() {
        let app = launchInSettings()
        XCTAssertTrue(app.staticTexts["Daily Targets"].waitForExistence(timeout: 10), "Targets section should render")
        XCTAssertTrue(app.staticTexts["Units"].exists, "Units section should render")
        let reset = app.buttons["Reset targets to defaults"]
        app.swipeUp()
        XCTAssertTrue(reset.waitForExistence(timeout: 5), "Data section should render after scrolling")
    }

    @MainActor
    func testCaloriesTargetCanBeTyped() {
        let app = launchInSettings()
        let field = app.textFields["Calories"]
        XCTAssertTrue(field.waitForExistence(timeout: 10), "Calories should be an editable field")

        field.tap()
        let existing = field.value as? String ?? ""
        field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: existing.count))
        field.typeText("1800")
        app.buttons["Done"].firstMatch.tap()

        XCTAssertEqual(field.value as? String, "1800", "Typed calorie target should stick")
    }

    @MainActor
    func testAppleHealthSectionRenders() {
        let app = launchInSettings()
        app.swipeUp(); app.swipeUp()
        let healthRow = app.staticTexts["Apple Health"]
        XCTAssertTrue(healthRow.waitForExistence(timeout: 5), "Apple Health row should render")
        healthRow.tap()
        XCTAssertTrue(app.switches["Sync nutrition to Apple Health"].waitForExistence(timeout: 3),
                      "Nutrition sync toggle should exist on the detail screen")
        XCTAssertTrue(app.buttons["Remove this app’s data from Apple Health"].exists,
                      "The destructive remove action should be present")
    }

    @MainActor
    func testAboutShowsDataSourceAttribution() {
        let app = launchInSettings()
        let about = app.buttons["About"]
        app.swipeUp(); app.swipeUp()
        XCTAssertTrue(about.waitForExistence(timeout: 5), "About row should be reachable")
        about.tap()
        XCTAssertTrue(app.navigationBars["About"].waitForExistence(timeout: 5), "About should open")

        let off = app.staticTexts.containing(
            NSPredicate(format: "label CONTAINS %@", "Open Food Facts")).firstMatch
        app.swipeUp(); app.swipeUp()
        XCTAssertTrue(off.waitForExistence(timeout: 3), "Open Food Facts attribution should be visible")
        XCTAssertTrue(app.links["openfoodfacts.org"].exists || app.buttons["openfoodfacts.org"].exists,
                      "A tappable Open Food Facts link should be present")
    }

    @MainActor
    func testGoalWizardCanBeCancelled() {
        let app = launchInSettings()
        let setBtn = app.buttons["Set targets from a goal"]
        XCTAssertTrue(setBtn.waitForExistence(timeout: 10))
        setBtn.tap()

        XCTAssertTrue(app.staticTexts["Welcome"].waitForExistence(timeout: 5), "Wizard should open on Welcome")
        app.buttons["Cancel"].tap()
        XCTAssertTrue(app.staticTexts["Daily Targets"].waitForExistence(timeout: 5),
                      "Cancel should return to Settings without forcing the wizard")
    }

    @MainActor
    func testFullResetReturnsToSetupWizard() {
        let app = launchInSettings()
        let erase = app.buttons["Erase All Data & Start Over"]
        app.swipeUp(); app.swipeUp()
        XCTAssertTrue(erase.waitForExistence(timeout: 5), "Erase button should render")
        erase.tap()

        let confirm = app.buttons["Erase Everything"]
        XCTAssertTrue(confirm.waitForExistence(timeout: 5), "Confirmation should appear")
        confirm.tap()

        XCTAssertTrue(app.staticTexts["Welcome"].waitForExistence(timeout: 5),
                      "Setup wizard should relaunch (on Welcome) after a full reset")
    }

    @MainActor
    func testOnboardingUnitsCanBeSwitched() {
        let app = launchInSettings()
        app.swipeUp(); app.swipeUp()
        let erase = app.buttons["Erase All Data & Start Over"]
        XCTAssertTrue(erase.waitForExistence(timeout: 5))
        erase.tap()
        let confirm = app.buttons["Erase Everything"]
        XCTAssertTrue(confirm.waitForExistence(timeout: 5))
        confirm.tap()

        // Welcome → Try a Meal → Your Goal → pick a goal → Diet → About You.
        advanceToGoal(app)
        app.staticTexts["Maintain weight"].tap()
        app.buttons["Continue"].tap()
        XCTAssertTrue(app.staticTexts["Diet Style"].waitForExistence(timeout: 5), "Diet Style step should appear")
        XCTAssertTrue(app.staticTexts["Keto"].exists, "Diet styles should be listed")
        app.buttons["Continue"].tap()
        XCTAssertTrue(app.staticTexts["About You"].waitForExistence(timeout: 5))

        // The body step has a Units toggle; the weight chip shows the unit (kg/lb).
        app.buttons["Imperial"].tap()
        XCTAssertTrue(app.staticTexts["lb"].waitForExistence(timeout: 3), "Imperial weight chip shows lb")
        app.buttons["Metric"].tap()
        XCTAssertTrue(app.staticTexts["kg"].waitForExistence(timeout: 3), "Metric weight chip shows kg")
    }
}
