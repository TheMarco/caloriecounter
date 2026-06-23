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

        // Double-tap selects the existing number; typing then replaces it.
        field.doubleTap()
        field.typeText("1800")
        app.buttons["Done"].tap()

        XCTAssertEqual(field.value as? String, "1800", "Typed calorie target should stick")
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

        // Step 0: pick a goal, then continue to the "About You" body step.
        let goal = app.staticTexts["Maintain weight"]
        XCTAssertTrue(goal.waitForExistence(timeout: 5))
        goal.tap()
        app.buttons["Continue"].tap()
        XCTAssertTrue(app.staticTexts["About You"].waitForExistence(timeout: 5))

        // The body step now exposes a Units toggle that switches weight units.
        app.buttons["Imperial"].tap()
        XCTAssertTrue(app.staticTexts["Weight (lb)"].waitForExistence(timeout: 3),
                      "Imperial should show weight in lb")
        app.buttons["Metric"].tap()
        XCTAssertTrue(app.staticTexts["Weight (kg)"].waitForExistence(timeout: 3),
                      "Metric should show weight in kg")
    }
}
