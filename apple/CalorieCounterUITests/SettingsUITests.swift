//
//  SettingsUITests.swift
//  Smoke test: the Settings tab renders targets, units, security, and export.
//

import XCTest

final class SettingsUITests: XCTestCase {

    override func setUp() { continueAfterFailure = false }

    @MainActor
    func testSettingsTabRenders() {
        let app = XCUIApplication()
        app.launchArguments += ["-uitest"]
        app.launch()

        let settingsTab = app.tabBars.buttons["Settings"]
        XCTAssertTrue(settingsTab.waitForExistence(timeout: 10), "Settings tab should exist")
        settingsTab.tap()

        XCTAssertTrue(app.staticTexts["Daily Targets"].waitForExistence(timeout: 5), "Targets section should render")
        XCTAssertTrue(app.staticTexts["Units"].exists, "Units section should render")
        // Scroll to the data section and confirm the export/reset controls built.
        let reset = app.buttons["Reset targets to defaults"]
        app.swipeUp()
        XCTAssertTrue(reset.waitForExistence(timeout: 5), "Data section should render after scrolling")
    }

    @MainActor
    func testCaloriesTargetCanBeTyped() {
        let app = XCUIApplication()
        app.launchArguments += ["-uitest"]
        app.launch()

        app.tabBars.buttons["Settings"].tap()
        let field = app.textFields["Calories"]
        XCTAssertTrue(field.waitForExistence(timeout: 10), "Calories should be an editable field")

        // Tapping puts the caret at the end; clear the existing value, then type the new one.
        field.tap()
        let existing = field.value as? String ?? ""
        field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: existing.count))
        field.typeText("1800")
        app.buttons["Done"].tap()

        XCTAssertEqual(field.value as? String, "1800", "Typed calorie target should stick")
    }

    @MainActor
    func testAppleHealthSectionRenders() {
        let app = XCUIApplication()
        app.launchArguments += ["-uitest"]
        app.launch()

        app.tabBars.buttons["Settings"].tap()
        app.swipeUp(); app.swipeUp()
        XCTAssertTrue(app.staticTexts["Apple Health"].waitForExistence(timeout: 5), "Apple Health section should render")
        // Opt-in controls present (toggle flip + persistence is covered by unit tests).
        XCTAssertTrue(app.switches["Sync nutrition to Apple Health"].waitForExistence(timeout: 3),
                      "Nutrition sync toggle should exist")
        XCTAssertTrue(app.buttons["Remove this app’s data from Apple Health"].exists,
                      "The destructive remove action should be present")
    }

    @MainActor
    func testAboutShowsUSDAAttribution() {
        let app = XCUIApplication()
        app.launchArguments += ["-uitest"]
        app.launch()

        app.tabBars.buttons["Settings"].tap()
        let about = app.buttons["About"]
        app.swipeUp(); app.swipeUp()
        XCTAssertTrue(about.waitForExistence(timeout: 5), "About row should be reachable")
        about.tap()
        XCTAssertTrue(app.navigationBars["About"].waitForExistence(timeout: 5), "About should open")

        // Data Sources is near the bottom of the (lazily-rendered) list.
        let usda = app.staticTexts.containing(
            NSPredicate(format: "label CONTAINS %@", "USDA FoodData Central")).firstMatch
        app.swipeUp(); app.swipeUp()
        XCTAssertTrue(usda.waitForExistence(timeout: 3), "USDA FoodData Central attribution should be visible")
        XCTAssertTrue(app.links["fdc.nal.usda.gov"].exists || app.buttons["fdc.nal.usda.gov"].exists,
                      "A tappable FoodData Central link should be present")
    }

    @MainActor
    func testGoalWizardCanBeCancelled() {
        let app = XCUIApplication()
        app.launchArguments += ["-uitest"]
        app.launch()

        app.tabBars.buttons["Settings"].tap()
        let setBtn = app.buttons["Set targets from a goal"]
        XCTAssertTrue(setBtn.waitForExistence(timeout: 10))
        setBtn.tap()

        XCTAssertTrue(app.staticTexts["Your Goal"].waitForExistence(timeout: 5), "Wizard should open")
        app.buttons["Cancel"].tap()
        XCTAssertTrue(app.staticTexts["Daily Targets"].waitForExistence(timeout: 5),
                      "Cancel should return to Settings without forcing the wizard")
    }

    @MainActor
    func testFullResetReturnsToSetupWizard() {
        let app = XCUIApplication()
        app.launchArguments += ["-uitest"]
        app.launch()

        let settingsTab = app.tabBars.buttons["Settings"]
        XCTAssertTrue(settingsTab.waitForExistence(timeout: 10))
        settingsTab.tap()

        // Reach the danger-zone button at the bottom.
        let erase = app.buttons["Erase All Data & Start Over"]
        app.swipeUp(); app.swipeUp()
        XCTAssertTrue(erase.waitForExistence(timeout: 5), "Erase button should render")
        erase.tap()

        // Confirm the destructive action, then the setup wizard should appear.
        let confirm = app.buttons["Erase Everything"]
        XCTAssertTrue(confirm.waitForExistence(timeout: 5), "Confirmation should appear")
        confirm.tap()

        XCTAssertTrue(app.staticTexts["Your Goal"].waitForExistence(timeout: 5),
                      "Setup wizard should relaunch after a full reset")
    }

    @MainActor
    func testOnboardingUnitsCanBeSwitched() {
        let app = XCUIApplication()
        app.launchArguments += ["-uitest"]
        app.launch()

        // Reach the setup wizard via a full reset.
        let settingsTab = app.tabBars.buttons["Settings"]
        XCTAssertTrue(settingsTab.waitForExistence(timeout: 10))
        settingsTab.tap()
        app.swipeUp(); app.swipeUp()
        let erase = app.buttons["Erase All Data & Start Over"]
        XCTAssertTrue(erase.waitForExistence(timeout: 5))
        erase.tap()
        let confirm = app.buttons["Erase Everything"]
        XCTAssertTrue(confirm.waitForExistence(timeout: 5))
        confirm.tap()

        // Step 0: pick a goal → Continue. Step 1: Diet Style (has a default) →
        // Continue. Step 2: the "About You" body step.
        let goal = app.staticTexts["Maintain weight"]
        XCTAssertTrue(goal.waitForExistence(timeout: 5))
        goal.tap()
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
