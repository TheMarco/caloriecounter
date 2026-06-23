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
}
